# Jeff 1.1 for JevBench

This repository serves the Jeff 1.1 decision models with the settings we submit to JevBench. It contains no model code
of its own: it installs our serving code, [jeff-serve](https://github.com/j-geuter/Jeff), at the release we tested
(v1.4.0), and starts it with these settings, which cannot be changed from the command line:

- **Reasoning when unsure** (`--reasoning on`): every question is first answered in one forward pass. If the
  model's calibrated confidence is below a threshold for the question's type, the base model writes a short reasoning
  and the model answers again after reading it. The reasoning settings we chose for JevBench are in `settings/`
  (Jeff-1.1-Large: at most 256 tokens; Jeff-1.1-Medium: 512; Jeff-1.1-Qwen-4B: 256); Jeff-1.1-Qwen-27B uses its
  released settings (512).
- **JevBench limits** (`--jevbench-limits on`), which keep the model within the board's limits:
  - **every decision is answered within 8.5 s** of the request's arrival (JevBench counts a decision over 10 s as
    failed): a reasoning that could not be read in time is dropped, and the question keeps its one-pass answer;
  - the mean number of output tokens per question, over everything the server has answered, never exceeds a limit
    (Jeff-1.1-Large and Jeff-1.1-Qwen-27B: 35; Jeff-1.1-Medium: 224; Jeff-1.1-Qwen-4B: 143);
  - no new reasoning while more than 45% of the last 1,000 questions reasoned (after the first 100).
- **Faster reasoning when the GPU has room** (`--fast-reasoning`): with memory for the model twice, the base model's
  weights are kept as a second copy and the reasoning is written 2-5x faster, so more reasonings finish in time.
  Otherwise the reasoning is written by the model itself with the adapter switched off (no extra memory). This
  compiles at startup (up to about 10 minutes for the 31B).
- **One request at a time**, as JevBench sends them; no batching.

The output tokens of each answer are reported in `usage.output_tokens`.

| Model | Base model | Download | GPU memory | Revision |
|---|---|---|---|---|
| [jgeuter/Jeff-1.1-Large](https://huggingface.co/jgeuter/Jeff-1.1-Large) | Gemma 4 31B | 64 GB | 80 GB | `970c21af246a44c5527f7109fca129ab6015c941` |
| [jgeuter/Jeff-1.1-Qwen-27B](https://huggingface.co/jgeuter/Jeff-1.1-Qwen-27B) | Qwen3.6-27B | 56 GB | 80 GB | `8c2553e7f8262e00c4157564ebedf9d35e36db23` |
| [jgeuter/Jeff-1.1-Medium](https://huggingface.co/jgeuter/Jeff-1.1-Medium) | Gemma 4 12B | 26 GB | 40 GB | `540c40924dd67c715d3367309ba6744bac754b00` |
| [jgeuter/Jeff-1.1-Qwen-4B](https://huggingface.co/jgeuter/Jeff-1.1-Qwen-4B) | Qwen3.5-4B | 9 GB | 16 GB | `5401940b5a8c959cba82187ebfa2dce5a21abc0a` |

## Run with Docker

Download the weights first, to any folder with enough space (`hf` comes with `pip install huggingface_hub`):

```bash
export JEFF_DIR=$HOME/models/Jeff-1.1-Large
hf download jgeuter/Jeff-1.1-Large --revision 970c21af246a44c5527f7109fca129ab6015c941 --local-dir "$JEFF_DIR"
docker build -t jeff-jevbench .
docker run --gpus '"device=0"' -v "$JEFF_DIR":/model:ro -p 127.0.0.1:8013:8013 jeff-jevbench
```

The server answers at `http://127.0.0.1:8013/v1/systemone` (TypeSafe System One wire format) once it prints
`serving ... on`. It reads the weights from `/model` and needs no network access. Loading takes a few minutes; when the
GPU can hold the model twice, compiling the faster reasoning adds up to about 10 minutes (31B on an H200).

## Run without Docker

Python 3.12 and a C compiler (e.g. `gcc`; Triton, which torch uses, compiles a small helper on the first request):

```bash
pip install -r requirements.txt
pip install --no-deps "jeff @ git+https://github.com/j-geuter/Jeff@v1.4.0"
./entrypoint.sh jgeuter/Jeff-1.1-Large --revision 970c21af246a44c5527f7109fca129ab6015c941 --host 127.0.0.1 --port 8013
```

## Check it

```bash
curl -s http://127.0.0.1:8013/v1/systemone -H 'Content-Type: application/json' -d '{
  "state": {"ticket": "I was charged twice for order #4411 and want the second charge refunded."},
  "questions": {"route": {"type": "choice", "instructions": "Which team should handle this ticket?",
                          "criteria": {"billing": "Payments", "technical": "Bugs", "shipping": "Delivery"}},
                "urgent": {"type": "noul", "instructions": "Does this ticket need a reply today?"}}}'
```

The response holds `answers` (`route.choice` should be `billing`), `usage` with the input and output tokens, and
`runtime` with the settings above (`runtime.reasoning`).

## Notes

- Yes/no answers between 0.2 and 0.8 are moved to 0.199 or 0.801 (JevBench counts that band as wrong).
- Inputs over 8,192 tokens keep their question-relevant parts; questions with more than 16 options (up to 256) are
  answered in groups of 16.
- The public serving code ([j-geuter/Jeff](https://github.com/j-geuter/Jeff)) has more options (batching, vLLM for the
  reasoning, other limits) and other defaults; this repository fixes the settings of our JevBench results.

License: Apache-2.0 (LICENSE, NOTICE). The model weights have their own licenses (see the model cards).
