Ricoh2C02Bus ppuBus;

class Ricoh2C02Bus {
  int[] nameTable1 = new int[0x400]; // either nametable array holds BOTH the nametable AND its attribute table.
  int[] nameTable2 = new int[0x400];

  int[][] patternTables; // holds char rom data (or allows for 8kb of char ram)

  int[] currentlySelectedBanks = {0, 1};

  int[] paletteRam = new int[32];

  int ppuDataReadBuffer = 0;

  // explicit variables determining how data is read and written in the ppu (set by cartridge)
  boolean chrRamUsed = false;
  boolean nametableMirroring = false; // false = horizontal, true = vertical
  
  boolean vramPageSelect = false;

  // open bus
  int openBus = 0;

  void write(int address, int value) {
    if (address >= 0x3F00) { // palette
      paletteRam[(address - 0x3F00) % 0x20] = value;

      if ((address - 0x3F00) % 4 == 0) {
        paletteRam[(address - 0x3F00) % 0x10] = value;
        paletteRam[((address - 0x3F00) % 0x10) + 0x10] = value;
      }
    }

    if (address >= 0 && address < 0x2000) { // checks for char ram, and writes if applicable.
      if (chrRamUsed) {
        patternTables[0][address] = value;
      }
    }

    if (address >= 0x2000 && address < 0x2400) { // nametable1
      switch (cpuBus.mapper) {
        case 1: // MMC1
          switch(cpuBus.mmc1Control & 3) {
            case 0:
              nameTable1[address - 0x2000] = value;
              break;
            case 1:
              nameTable2[address - 0x2000] = value;
              break;
            case 2:
            case 3:
              nameTable1[address - 0x2000] = value;
              break;
          }
          break;
        case 7: // AxROM
          if (vramPageSelect) {
            nameTable2[address - 0x2000] = value;
          } else {
            nameTable1[address - 0x2000] = value;
          }
          break;
        default:
          nameTable1[address - 0x2000] = value;
          break;
      }
    }

    if (address >= 0x2400 && address < 0x2800) { // nametable2 or nametable1 (mirror)
      switch (cpuBus.mapper) {
        case 1: // MMC1
          switch(cpuBus.mmc1Control & 3) {
            case 0:
              nameTable1[address - 0x2400] = value;
              break;
            case 1:
              nameTable2[address - 0x2400] = value;
              break;
            case 2:
              nameTable2[address - 0x2400] = value;
              break;
            case 3:
              nameTable1[address - 0x2400] = value;
              break;
          }
          break;
        case 7: // AxROM
          if (vramPageSelect) {
            nameTable2[address - 0x2400] = value;
          } else {
            nameTable1[address - 0x2400] = value;
          }
          break;
        default:
          if (nametableMirroring) {
            nameTable1[address - 0x2400] = value;
          } else {
            nameTable2[address - 0x2400] = value;
          }
          break;
      }
    }

    if (address >= 0x2800 && address < 0x2C00) { // nametable1 (mirror) or nametable 2
      switch (cpuBus.mapper) {
        case 1: // MMC1
          switch(cpuBus.mmc1Control & 3) {
            case 0:
              nameTable1[address - 0x2800] = value;
              break;
            case 1:
              nameTable2[address - 0x2800] = value;
              break;
            case 2:
              nameTable1[address - 0x2800] = value;
              break;
            case 3:
              nameTable2[address - 0x2800] = value;
              break;
          }
          break;
        case 7: // AxROM
          if (vramPageSelect) {
            nameTable2[address - 0x2800] = value;
          } else {
            nameTable1[address - 0x2800] = value;
          }
          break;
        default:
          if (nametableMirroring) {
            nameTable2[address - 0x2800] = value;
          } else {
            nameTable1[address - 0x2800] = value;
          }
          break;
      }
    }

    if (address >= 0x2C00 && address < 0x3000) { // nametable2 (mirror)
      switch (cpuBus.mapper) {
        case 1: // MMC1
          switch(cpuBus.mmc1Control & 3) {
            case 0:
              nameTable1[address - 0x2C00] = value;
              break;
            case 1:
              nameTable2[address - 0x2C00] = value;
              break;
            case 2:
            case 3:
              nameTable2[address - 0x2C00] = value;
              break;
          }
          break;
        case 7: // AxROM
          if (vramPageSelect) {
            nameTable2[address - 0x2C00] = value;
          } else {
            nameTable1[address - 0x2C00] = value;
          }
          break;
        default:
          nameTable2[address - 0x2C00] = value;
          break;
      }
    }
  }

  int read(int address) {
    if (address >= 0x3F00) { // palette
      openBus = paletteRam[(address - 0x3F00) % 0x20] & 0b00111111;
      if ((ppu.ppuMask & 1) == 1) openBus &= 0b11110000;
      return openBus;
    }

    if (address >= 0x2000 && address < 0x2400) { // nametable1
      switch(cpuBus.mapper) {
        case 1: // MMC1
          switch(cpuBus.mmc1Control & 3) {
            case 0:
              openBus = nameTable1[address - 0x2000];
              break;
            case 1:
              openBus = nameTable2[address - 0x2000];
              break;
            case 2:
            case 3:
              openBus = nameTable1[address - 0x2000];
              break;
          }
          return openBus;
        case 7: // AxROM
          openBus = vramPageSelect ? nameTable2[address - 0x2000] : nameTable1[address - 0x2000];
          return openBus;
        default:
          openBus = nameTable1[address - 0x2000];
          return openBus;
      }
    }

    if (address >= 0x2400 && address < 0x2800) { // nametable2 or nametable1 (mirror)
      switch(cpuBus.mapper) {
        case 1: // MMC1
          switch(cpuBus.mmc1Control & 3) {
            case 0:
              openBus = nameTable1[address - 0x2400];
              break;
            case 1:
              openBus = nameTable2[address - 0x2400];
              break;
            case 2:
              openBus = nameTable2[address - 0x2400];
              break;
            case 3:
              openBus = nameTable1[address - 0x2400];
              break;
          }
          return openBus;
        case 7: // AxROM
          openBus = vramPageSelect ? nameTable2[address - 0x2400] : nameTable1[address - 0x2400];
          return openBus;
        default:
          if (nametableMirroring) {
            openBus = nameTable1[address - 0x2400];
            return openBus;
          } else {
            openBus = nameTable2[address - 0x2400];
            return openBus;
          }
      }
    }

    if (address >= 0x2800 && address < 0x2C00) { // nametable1 (mirror) or nametable 2
      switch(cpuBus.mapper) {
        case 1: // MMC1
          switch(cpuBus.mmc1Control & 3) {
            case 0:
              openBus = nameTable1[address - 0x2800];
              break;
            case 1:
              openBus = nameTable2[address - 0x2800];
              break;
            case 2:
              openBus = nameTable1[address - 0x2800];
              break;
            case 3:
              openBus = nameTable2[address - 0x2800];
              break;
          }
          return openBus;
        case 7: // AxROM
          openBus = vramPageSelect ? nameTable2[address - 0x2800] : nameTable1[address - 0x2800];
          return openBus;
        default:
          if (nametableMirroring) {
            openBus = nameTable2[address - 0x2800];
            return openBus;
          } else {
            openBus = nameTable1[address - 0x2800];
            return openBus;
          }
      }
    }

    if (address >= 0x2C00 && address < 0x3000) { // nametable2 (mirror)
      switch(cpuBus.mapper) {
        case 1: // MMC1
          switch(cpuBus.mmc1Control & 3) {
            case 0:
              openBus = nameTable1[address - 0x2C00];
              break;
            case 1:
              openBus = nameTable2[address - 0x2C00];
              break;
            case 2:
            case 3:
              openBus = nameTable2[address - 0x2C00];
              break;
          }
          return openBus;
        case 7: // AxROM
          openBus = vramPageSelect ? nameTable2[address - 0x2C00] : nameTable1[address - 0x2C00];
          return openBus;
        default:
          openBus = nameTable2[address - 0x2C00];
          return openBus;
      }
    }

    // pattern table
    if (address < 0x2000) {
      if (chrRamUsed) {
        openBus = patternTables[0][address];
      } else {
        if (address < 0x1000) {
          openBus = patternTables[currentlySelectedBanks[0] % patternTables.length][address];
        } else {
          openBus = patternTables[currentlySelectedBanks[1] % patternTables.length][address - 0x1000];
        }
      }
      return openBus;
    }

    return openBus;
  }
}
