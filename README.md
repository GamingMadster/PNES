# ProcessingNES (PNES)
A Nintendo Entertainment System emulator written in Java using the Processing IDE.

> [!WARNING]
> This emulator is heavily unoptimized in its current state. Most games will not run at a full 60 fps.

PNES currently passes `89 / 139` tests on the [AccuracyCoin](https://github.com/100thCoin/AccuracyCoin) test rom.
<p align="center">
  <img src="images/test_results.png" width="512" height="480" alt="Test Results">
</p>

## Controls

| Action | Key |
| ------ | --- |
| D-Pad Left | `Left Arrow` |
| D-Pad Right | `Right Arrow` | 
| D-Pad Down | `Down Arrow` |
| D-Pad Up | `Up Arrow` |
| Start | `Enter` |
| Select | `Space` |
| B Button | `Z` |
| A Button | `X` |

## Mapper Support 
| Mapper|Support Status |
| ----- | ------------- |
| AxROM | Supported ✅ |
| CNROM | Supported ✅ |
| MMC1  | Supported ✅ |
| MMC2  |Unsupported ❌ (Planned)|
| MMC3  |Unsupported ❌ (Planned)|
| NROM  | Supported ✅ |
| UNROM | Supported ✅ |

Other mappers may partially function due to how .nes files are loaded in this emulator.

## Dependencies
- [OpenJDK 17](https://openjdk.org/projects/jdk/17/)
- [LazyGui](https://github.com/KrabCode/LazyGui)

## Compiling
To compile the sketch, download the files under `src`, and use the [Processing IDE](https://processing.org/download) or Intellj IDEA IDE with the Processing plugin installed to compile a standalone binary.

You can run the sketch without compiling by loading `PNES.pde` within the Processing IDE and pressing the "Run" button.
