# Vehicle ownership model, based on the NHTS

# comment out when using --track-allocations so not so many mem files
# using Distributed; addprocs()
# @everywhere begin
#     using Pkg
#     Pkg.activate(Base.source_dir())
# end

using CSV, CodecZlib, Profile, DiscreteChoiceModels, Dagger, Optim, Tables
import Tables: columnnames

# to save space in the repo, data are gzipped. helper function to read a
# gzipped csv "straight" into JuliaDB (via a temporary file)
function read_gzipped_csv(file; cs=30000)
    open(GzipDecompressorStream, file) do is
        mktemp() do path, os
            write(os, read(is))
            DTable(Tables.rowtable(CSV.File(path)), cs)
        end
    end
end

Tables.columnnames(::Vector{NamedTuple{N, T}}) where {N, T} = N

function read_data(basepath; cs=30000)
    data = read_gzipped_csv(joinpath(basepath, "hhpub.csv.gz"), cs=cs)

    # topcode hhvehcnt
    data = map(r -> merge((hhveh_topcode=min(r.HHVEHCNT, 4),), pairs(r)), data)

    data = filter(data) do row
        row.HHSTATE in Set(["CA", "OR", "WA", "NV", "ID", "AZ", "UT", "CO", "NM", "MT", "TX", "OK", "NE", "WY", "ND", "SD"])
    end

    data
end

function run_model(data)
    multinomial_logit(
        @utility(begin
            0 ~ α0
            1 ~ α1 + β1homeown * (HOMEOWN == 2) + @dummy_code(β1, HH_RACE, [2, 3, 4, 5, 6, 97]) + β1_hhsize * HHSIZE
            2 ~ α2 + β2homeown * (HOMEOWN == 2) + @dummy_code(β2, HH_RACE, [2, 3, 4, 5, 6, 97]) + β2_hhsize * HHSIZE
            3 ~ α3 + β3homeown * (HOMEOWN == 2) + @dummy_code(β3, HH_RACE, [2, 3, 4, 5, 6, 97]) + β3_hhsize * HHSIZE
            4 ~ α4plus + β4plushomeown * (HOMEOWN == 2) + @dummy_code(β4plus, HH_RACE, [2, 3, 4, 5, 6, 97]) + β4plus_hhsize * HHSIZE

            α0 = 0, fixed
        end),
        :hhveh_topcode,
        data;
        verbose=:medium
    )
end

function main()
    data = read_data("test/data/nhts", cs=30000)
    model = run_model(data)

    println(summary(model))


end

rechunk(table, chunksize) = DTable(collect(table), chunksize)

main()