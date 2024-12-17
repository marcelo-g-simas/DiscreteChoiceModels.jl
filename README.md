# DiscreteChoiceModels.jl

This is a pure [Julia](https://julialang.org) package for estimating discrete choice/random utility models. The models supported so far are:

- Multinomial logit

Support is planned for:

- Nested logit
- Mixed logit

At this point, the package should be considered experimental.

The package allows specifying discrete choice models using an intuitive, expressive syntax. For instance, the following code reproduces [Biogeme's multinomial logit model](https://biogeme.epfl.ch/examples/swissmetro/01logit.html) in 28 lines of code, vs. 65 for the Biogeme example:

```julia
using DiscreteChoiceModels, CSV, DataFrames

# read and filter data, and create binary availability columns
data = CSV.read(replace(pathof(DiscreteChoiceModels), "src/DiscreteChoiceModels.jl" => "") * "/test/data/biogeme_swissmetro.dat", DataFrame, delim='\t')

data = data[in.(data.PURPOSE, [Set([1, 3])]) .& (data.CHOICE .!= 0), :]

data.avtr = (data.TRAIN_AV .== 1) .& (data.SP .!= 0)
data.avsm = data.SM_AV .== 1
data.avcar = (data.CAR_AV .== 1) .& (data.SP .!= 0)

model = multinomial_logit(
    @utility(begin
        1 ~ αtrain + βtravel_time * TRAIN_TT / 100 + βcost * (TRAIN_CO * (GA == 0)) / 100
        2 ~ αswissmetro + βtravel_time * SM_TT / 100 + βcost * SM_CO * (GA == 0) / 100
        3 ~ αcar + βtravel_time * CAR_TT / 100 + βcost * CAR_CO / 100

        αswissmetro = 0, fixed  # fix swissmetro ASC to zero 
    end),
    :CHOICE,
    data,
    availability=[
        1 => :avtr,
        2 => :avsm,
        3 => :avcar
    ]
)

summary(model)
```

## Specifying a model

Models are specified using the `@utility` macro. Utility functions are specified using `~`, where the left-hand side is the value in the choice vector passed into the model estimation function (which can be a number, string, etc.). Values on the right-hand side that start with α or β are quantities to estimate (which can be typed into a properly-configured Julia environment as `\alpha` and `\beta`), all other values are assumed to be variables in the dataset. For example,
`"car" ~ αcar + βtravel_time * travel_time_car`
specifies that the utility function for the choice "car" is an ASC plus a generic travel time coefficient multiplied by car travel time. By convention, α is used for alternative-specific constants, and β is used for coefficients, but the software treats them as interchangeable.

Starting values for coefficients can be specified using `=`. For example,
`αcar = 1.3247`
will start estimation for this coefficient at 1.3247. If a coefficient appears in a utility function specification without a starting value being defined, the starting value will be set to zero.

If a coefficient should be fixed (rather than estimated), this can be specified with a `, fixed` postfix:
`αcar = 0, fixed`
This is most commonly used with 0 to indicate a left-out ASC, but any value can be fixed for a coefficient.

If one choice outcome should not have any values in its utility function (i.e. it is the base outcome), that must be explicitly stated by declaring `"walk" ~ 0`

## Features

- Expressive syntax for model specification
- Many optimization algorithms available using [Optim.jl](https://github.com/JuliaNLSolvers/Optim.jl)
- Variance-covariance matrices estimated using [automatic differentiation](https://github.com/JuliaDiff/ForwardDiff.jl)

## Performance

It's good. (Benchmarks to come.)

`DiscreteChoiceModels` is designed to support multithreading to increase performance. Recently, the [Julia developers announced](https://julialang.org/blog/2023/07/PSA-dont-use-threadid/) that a previously-recommended pattern for multithreading software is no longer safe with the latest Julia versions. Until DiscreteChoiceModels is re-written to avoid this pattern, it is recommended that mixed logit models not use multithreading.
