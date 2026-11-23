"""Transcribe local practice audio with an existing offline Whisper model."""
from argparse import ArgumentParser
from pathlib import Path
from shutil import which
from subprocess import CalledProcessError, check_output


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("files", type=Path, nargs="+")
    args = parser.parse_args()

    if not (args.model_dir / "model.bin").is_file():
        parser.error("--model-dir must point to an existing CTranslate2 Whisper model")
    ffmpeg = which("ffmpeg")
    if ffmpeg is None:
        parser.error("FFmpeg must be available on PATH")
    for path in args.files:
        if not path.is_file():
            parser.error(f"File not found: {path}")

    try:
        import numpy as np
        from faster_whisper import WhisperModel
    except ImportError as exc:
        parser.error(f"Missing local ASR dependency: {exc.name}")

    model = WhisperModel(str(args.model_dir.resolve()), device="cpu",
                         compute_type="int8", local_files_only=True)
    for path in args.files:
        try:
            pcm = check_output([ffmpeg, "-nostdin", "-v", "error", "-i",
                                str(path.resolve()), "-ac", "1", "-ar", "16000",
                                "-f", "f32le", "-"])
        except CalledProcessError:
            parser.error(f"FFmpeg could not decode: {path}")
        if not pcm:
            parser.error(f"Empty audio: {path}")
        print(path.name, flush=True)
        segments, _ = model.transcribe(np.frombuffer(pcm, dtype="<f4"),
                                       language="en", beam_size=5, vad_filter=True)
        for segment in segments:
            print(f"{segment.start:.2f}-{segment.end:.2f} {segment.text.strip()}")


if __name__ == "__main__":
    main()
