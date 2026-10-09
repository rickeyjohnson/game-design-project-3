"""Generate original, deterministic ambience and Foley. No external dependencies."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
DEST = Path(__file__).resolve().parents[1] / "audio"
DEST.mkdir(exist_ok=True)
random.seed(7319)


def write(name, seconds, sample):
    data = bytearray()
    for i in range(int(RATE * seconds)):
        t = i / RATE
        value = max(-0.95, min(0.95, sample(t, seconds)))
        data.extend(struct.pack("<h", int(value * 32767)))
    with wave.open(str(DEST / (name + ".wav")), "wb") as stream:
        stream.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        stream.writeframes(data)


def tone(t, hz):
    return math.sin(t * hz * math.tau)


write("room", 12, lambda t, d: 0.14 * tone(t, 55) + 0.06 * tone(t, 55.25)
      + 0.018 * tone(t, 220) * (0.5 + 0.5 * tone(t, 0.25)) + 0.008 * random.uniform(-1, 1))
write("click", 0.14, lambda t, d: random.uniform(-1, 1) * 0.4 * math.exp(-t * 65)
      + tone(t, 850) * 0.12 * math.exp(-t * 90))
write("step", 0.24, lambda t, d: (random.uniform(-1, 1) * 0.12 + tone(t, 90) * 0.28) * math.exp(-t * 24))
write("pickup", 0.55, lambda t, d: (tone(t, 440) + tone(t, 660)) * 0.1 * math.sin(math.pi * t / d) * math.exp(-t * 6))
write("breath", 3.8, lambda t, d: random.uniform(-1, 1) * 0.085 * math.sin(math.pi * t / d) ** 2)
write("sting", 2.5, lambda t, d: (tone(t, 47 + t * 6) * 0.3 + tone(t, 69) * 0.12
      + random.uniform(-1, 1) * 0.025) * math.sin(math.pi * t / d) * math.exp(-t * 0.8))
write("power", 1.5, lambda t, d: (tone(t, 60) * 0.2 + tone(t, 120) * 0.1
      + random.uniform(-1, 1) * 0.09 * math.exp(-t * 10)) * math.sin(math.pi * t / d))
write("land", 0.32, lambda t, d: (tone(t, 76) * 0.34 + tone(t, 142) * 0.12
      + random.uniform(-1, 1) * 0.16) * math.exp(-t * 21))
print("Generated 8 original PCM audio clips in", DEST)
