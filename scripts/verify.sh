#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_dir"
export HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1
pnpm format:check
pnpm build
pnpm lint
pnpm typecheck
pnpm test
pnpm depcruise
pnpm depcruise:fixture
uv run ruff format --check bench core sdk-py tools
uv run ruff check bench core sdk-py tools
uv run mypy bench/src core/src sdk-py/src
pytest_args=()
model_weights=models/hushmark-tr/pytorch_model.bin
if [[ ! -f "$model_weights" ]]; then
  pytest_args+=(
    --deselect=core/tests/test_ner_backends.py::test_torch_backend_detects_turkish_person_from_offline_model
    --deselect=core/tests/test_ner_backends.py::test_torch_and_onnx_backends_have_span_parity_on_turkish_fixture
    --deselect=sdk-py/tests/test_integration.py::test_python_sdk_and_batch_example_against_real_local_stack
  )
  echo "Optional model-weight tests are not part of the source-only public mirror."
fi
uv run pytest "${pytest_args[@]}"
uv run lint-imports
uv run python tools/codegen/generate.py --check
uv run python tools/codegen/claims_lint.py
for private_path in research briefs hushmark PLAN.md PLAN-BRIEF.md EXECUTABLE-PLAN-PROMPT.md; do
  if [[ -e "$private_path" ]]; then echo "forbidden private path: $private_path" >&2; exit 1; fi
done
canary='HUSHMARK-CORPUS-'
canary+='CANARY-7f3a9d'
if rg -l --fixed-strings --hidden --glob '!.git/**' --glob '!node_modules/**' -- "$canary" .; then
  echo "corpus canary found" >&2
  exit 1
fi
if rg -n --hidden --glob '!.git/**' --glob '!node_modules/**' --glob '!.venv/**'   '([T]ODO|[T]BD|\.skip\(|pytest\.mark\.skip)' .; then
  echo "placeholder or skipped-test marker found" >&2
  exit 1
fi
echo "Standalone public-mirror verification passed."
