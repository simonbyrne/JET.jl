# %% setup
# --------

using Test, TypeProfiler, InteractiveUtils

import Core.Compiler:
    widenconst

import TypeProfiler:
    TPInterpreter, gen_virtual_lambda, profile_call, get_result,
    virtual_process!, report_errors, get_virtual_globalvar,
    ToplevelErrorReport, InferenceErrorReport

for sym in Symbol.(last.(Base.Fix2(split, '.').(string.(vcat(subtypes(TypeProfiler, ToplevelErrorReport),
                                                             subtypes(TypeProfiler, InferenceErrorReport),
                                                             )))))
    Core.eval(@__MODULE__, :(import TypeProfiler: $(sym)))
end

import Base:
    Fix1, Fix2

import Core.Compiler:
    ⊑

const CC = Core.Compiler

const FIXTURE_DIR = normpath(@__DIR__, "fixtures")
gen_virtualmod() = Core.eval(@__MODULE__, :(module $(gensym(:TypeProfilerTestVirtualModule)) end))

const ERROR_REPORTS_FROM_SUM_OVER_STRING = let
    interp, frame = profile_call(sum, String)
    @test !isempty(interp.reports)
    interp.reports
end

function test_sum_over_string(ers::AbstractVector)
    @test !isempty(ers)
    for target in ERROR_REPORTS_FROM_SUM_OVER_STRING
        @test any(ers) do er
            return er.msg == target.msg && er.sig == target.sig
        end
    end
end
test_sum_over_string(res::TypeProfiler.VirtualProcessResult) = test_sum_over_string(res.inference_error_reports)

function profile_toplevel!(s,
                           virtualmod = gen_virtualmod();
                           filename = "top-level",
                           actualmodsym = :Main,
                           interp = TPInterpreter(),
                           )
    return virtual_process!(s, filename, actualmodsym, virtualmod, interp)
end

function profile_file!(filename,
                       virtualmod = gen_virtualmod();
                       actualmodsym = :Main,
                       interp = TPInterpreter())
    return virtual_process!(read(filename, String), filename, actualmodsym, virtualmod, interp)
end

# %% test body
# ------------

@testset "TypeProfiler.jl" begin
    @testset "virtual process" begin
        include("test_virtualprocess.jl")
    end

    @testset "abstract interpretation" begin
        include("test_abstractinterpretation.jl")
    end

    @testset "tfuncs" begin
        include("test_tfuncs.jl")
    end
end

# # favorite
# # --------
#
# # never ends otherwise
# fib(n) = n ≤ 2 ? n : fib(n-1) + fib(n-2)
# @profile_call fib(100000) # ::Int
# @profile_call fib(100000.) # ::Float64
# @profile_call fib(100000 + 100000im) # report !
#
# # no matching method
# # ------------------
#
# # single match
# @profile_call sum("julia")
# @profile_call sum(Char[])
# @profile_call sum([]) # the actual error (i.e. no method for `zero(Any)`) gets buriled in the "Too many methods matched" heuristic
