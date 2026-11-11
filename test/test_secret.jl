module TestSecret

using Test
using Configurations

@option struct SecretInner
    token::String
end

@option struct SecretDB
    user::String = "admin"
    password::Secret{String}
    port::Secret{Int} = Secret(5432)
    api_key::Maybe{Secret{String}} = nothing
    inner::Maybe{Secret{SecretInner}} = nothing
    any_secret::Secret = Secret("x")
end

@testset "Secret" begin
    @testset "printing is masked" begin
        s = Secret("hunter2")
        for str in (sprint(show, s), repr(s), string(s), "$s",
                    sprint(show, MIME"text/plain"(), s), sprint(print, s))
            @test str == "Secret(\"********\")"
            @test !occursin("hunter2", str)
        end

        db = from_dict(SecretDB, Dict{String,Any}("password" => "hunter2", "api_key" => "abc"))
        for str in (repr(db), sprint(show, MIME"text/plain"(), db), string(db))
            @test !occursin("hunter2", str)
            @test !occursin("abc", str)
            @test occursin("Secret(\"********\")", str)
        end
    end

    @testset "reveal, equality, hash" begin
        s = Secret("hunter2")
        @test reveal(s) == "hunter2"
        @test Secret("a") == Secret("a")
        @test Secret("a") != Secret("b")
        @test isequal(Secret("a"), Secret("a"))
        @test hash(Secret("a")) == hash(Secret("a"))
        @test hash(Secret("a")) != hash("a")
    end

    @testset "convert" begin
        @test convert(Secret{String}, "a") === Secret{String}("a")
        @test convert(Secret{Float64}, Secret(1)) === Secret{Float64}(1.0)
        s = Secret("a")
        @test convert(Secret{String}, s) === s
        @test convert(Secret, s) === s
        @test convert(Secret, 1) === Secret(1)
    end

    @testset "parsing" begin
        db = from_dict(SecretDB, Dict{String,Any}("password" => "hunter2"))
        @test db.password isa Secret{String}
        @test reveal(db.password) == "hunter2"
        @test reveal(db.port) == 5432
        @test db.api_key === nothing
        @test db.inner === nothing

        d = Dict{String,Any}(
            "password" => "hunter2",
            "port" => 1234,
            "api_key" => "abc",
            "inner" => Dict{String,Any}("token" => "t"),
            "any_secret" => 1,
        )
        db = from_dict(SecretDB, d)
        @test reveal(db.port) === 1234
        @test reveal(db.api_key) == "abc"
        @test reveal(db.inner) == SecretInner("t")
        @test reveal(db.any_secret) === 1

        # keyword constructor and from_kwargs wrap plain values
        @test SecretDB(; password = "hunter2") == SecretDB(; password = Secret("hunter2"))
        @test reveal(from_kwargs(SecretDB; password = "pw").password) == "pw"

        @test_throws Exception from_dict(SecretDB, Dict{String,Any}("password" => 1))
    end

    @testset "serialization round-trip" begin
        db = SecretDB(; password = "hunter2", api_key = "abc", inner = SecretInner("t"))
        d = to_dict(db)
        @test d["password"] == "hunter2"
        @test d["port"] == 5432
        @test d["api_key"] == "abc"
        @test d["inner"] == Dict("token" => "t")
        @test from_dict(SecretDB, d) == db

        file = tempname() * ".toml"
        to_toml(file, db)
        @test from_toml(SecretDB, file) == db
    end
end

end # module
