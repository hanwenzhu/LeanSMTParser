import Lake
open Lake DSL

require «mathlib» from git "https://github.com/leanprover-community/mathlib4" @ "v4.9.1"

require «Duper» from git "https://github.com/leanprover-community/duper.git" @ "dev"

package QuerySMT {
  precompileModules := false
}

lean_lib QuerySMT

@[default_target]
lean_exe «querysmt» {
  root := `Main
}
