Ricoh2A03Bus cpuBus;

class Ricoh2A03Bus { // the console's main bus (primarily used by the CPU)
  byte[] rom = new byte[0];
  int[] ram = new int[0x800]; // ram (has a size of $0800, and is mirrored up to $1FFF)
  int[] prgRam = new int[0x2000]; // work ram used by some mappers (located at $6000 - $7FFF when present)
  int[][] romBanks = null; // rom (has a variable size, in chunks of 16kb)
  int mapper = 0;

  int[] currentlySelectedBanks = {0, 1};

  int openBus = 0; // open bus behavior variable
  int ppuOpenBus = 0; // open bus except ppu

  int ctrl1Value = 0;
  int ctrl1Poll = 0;
  int ctrl1 = 0;
  
  // mapper specific values
  int mmc1Shift = 0b100000;
  int mmc1Control = 0x0C;

  void write(int address, int value) { // write a value to the main bus
    value &= 255; // clamp the value that is being written to 255 (to do proper overflow behavior)
    openBus = value;

    if (address < 0x2000) { // ram WRITE
      ram[address % 0x800] = value;
    }
    
    if (address >= 0x6000 & address < 0x8000) { // prg ram WRITE
      prgRam[address - 0x6000] = value;
    }
    
    // apu
    if (address >= 0x4000 && address <= 0x4003) {
      switch(address - 0x4000) {
        case 0:
          apu.pulse1Loop = (value & 0x20) > 0;            // halt flag
          apu.pulse1.width(apu.DUTY_CYCLE[value >> 6]);   // duty cycle
          apu.pulse1ConstantVolume = (value & 0x10) != 0; // constant volume
          apu.pulse1Volume = value & 0x0F;                // envelope
          break;
          
        case 1: // sweep
          apu.pulse1SweepEnabled = (value & 0x80) != 0;
          apu.pulse1SweepNegate = (value & 0x08) != 0;
          apu.pulse1Sweep = value & 0x07;
          break;
        
        case 2: // timer low
          apu.pulse1Timer = (apu.pulse1Timer & 0x700) | value;
          break;
          
        case 3: // length counter + timer high
          apu.pulse1Timer = (apu.pulse1Timer & 0xFF) | ((value & 0b111) << 8);
          
          if (apu.pulse1.isPlaying()) {
            apu.pulse1Counter = apu.LENGTH_COUNTER[value >> 3];
          }
          break;
      }
    }
    
    if (address >= 0x4004 && address <= 0x4007) {
      switch(address - 0x4004) {
        case 0:
          apu.pulse2Loop = (value & 0x20) > 0;            // halt flag
          apu.pulse2.width(apu.DUTY_CYCLE[value >> 6]);   // duty cycle
          apu.pulse2ConstantVolume = (value & 0x10) != 0; // constant volume
          apu.pulse2Volume = value & 0x0F;                // envelope
          break;
          
        case 1: // sweep
          apu.pulse2SweepEnabled = (value & 0x80) != 0;
          apu.pulse2SweepNegate = (value & 0x08) != 0;
          apu.pulse2Sweep = value & 0x07;
          break;
        
        case 2:
          apu.pulse2Timer = (apu.pulse2Timer & 0x700) | value;
          break;
          
        case 3:
          apu.pulse2Timer = (apu.pulse2Timer & 0xFF) | ((value & 0b111) << 8);
          
          if (apu.pulse2.isPlaying()) apu.pulse2Counter = apu.LENGTH_COUNTER[value >> 3];
          break;
      }
    }
    
    if (address >= 0x4008 && address <= 0x400B) {
      switch(address - 0x4008) {
        case 0:
          apu.triangleControl = (value & 0x80) > 0; // control flag + halt flag
          apu.triangleLinearCounter = value & 0x7F;
          break;
          
        case 2:
          apu.triangleTimer = (apu.triangleTimer & 0x700) | value;
          break;
          
        case 3:
          apu.triangleTimer = (apu.triangleTimer & 0xFF) | ((value & 0b111) << 8);
          
          if (apu.triangle.isPlaying()) apu.triangleCounter = apu.LENGTH_COUNTER[value >> 3];
          break;
      }
    }
    
    if (address == 0x4015) {
      if ((value & 1) == 1) apu.pulse1.play(); else {
        apu.pulse1.stop();
        apu.pulse1Counter = 0;
      }
      if ((value & 2) == 2) apu.pulse2.play(); else {
        apu.pulse2.stop();
        apu.pulse2Counter = 0;
      }
    }
    
    if (address == 0x4017) {
      if ((value >> 7) == 1) apu.clockLengthCounter(); // HACK
      apu.mode = value >> 7;
      apu.seqStep = 0;
      if ((value & 0x40) != 0) apu.interruptInhibit = false;
    }
    
     // PPU registers
    if (address >= 0x2000 && address < 0x4000 && !ppu.firstFrame) {
      ppuOpenBus = value;

      switch(((address - 0x2000) & 7)) {
        case 0: // ppuCtrl
          ppu.ppuCtrl = value;
  
          if (ppu.ppuCtrl >> 7 == 0) {
            ppu.hitNmi = false;
          }
  
          ppu.t &= 0b111001111111111;
          ppu.t |= (ppu.ppuCtrl & 0b11) << 10;
          
          // for debugging...
          if (debugBooleans[2]) {
            ppu.screen.pixels[ppu.dot + ppu.scanline * ppu.screen.width] = color(150, 69, 69);
          }
          break;
  
        case 1: // ppuMask
          ppu.ppuMask = value;
          
          ppu.renderUpdateDelay = 3;
          
          // for debugging...
          if (debugBooleans[2]) {
            ppu.screen.pixels[ppu.dot + ppu.scanline * ppu.screen.width] = color(142, 51, 255);
          }
          break;
  
        case 3: // oamAddr
          ppu.oamAddr = value;
          
          // for debugging...
          if (debugBooleans[2]) {
            ppu.screen.pixels[ppu.dot + ppu.scanline * ppu.screen.width] = color(255, 132, 224);
          }
          break;
  
        case 4: // oamData
          ppu.oam[ppu.oamAddr] = value;
          ppu.oamAddr = (ppu.oamAddr + 1) & 0xFF;
          
          // for debugging...
          if (debugBooleans[2]) {
            ppu.screen.pixels[ppu.dot + ppu.scanline * ppu.screen.width] = color(250, 255, 57);
          }
          break;
  
        case 5: // ppuScroll
          if (ppu.w) {
            ppu.t &= 0b000110000011111;
            ppu.t |= (value & 7) << 12;
            ppu.t |= (value >> 3) << 5;
          } else {
            ppu.t &= 0b111111111000000;
            ppu.t |= value >> 3;
  
            ppu.fineX = value & 7;
          }
  
          ppu.w = !ppu.w;
          
          // for debugging...
          if (debugBooleans[2]) {
            ppu.screen.pixels[ppu.dot + ppu.scanline * ppu.screen.width] = color(46, 255, 40);
          }
          break;
  
        case 6: // ppuAddr
          // depending on the state of ppu.w, either write the hi-byte of ppu.t, or write the lo-byte of ppu.t and copy ppu.t to ppu.v.
          // ppu.t (Temporary Address)
          // ppu.v (Actual Address)
          if (ppu.w) {
            ppu.t &= 0xFF00;
            ppu.t |= value;
  
            ppu.v = ppu.t;
          } else {
            ppu.t &= 0x00FF;
            ppu.t |= (value & 0b00111111) << 8;
          }
  
          ppu.w = !ppu.w;
          
          // for debugging...
          if (debugBooleans[2]) {
            ppu.screen.pixels[ppu.dot + ppu.scanline * ppu.screen.width] = color(61, 45, 255);
          }
          break;
  
        case 7: // ppuData
          // write to the ppuBus the value, then increment based on bit 2 of ppuCtrl.
          ppuBus.write(ppu.v, value);
          
          if ((ppu.ppuCtrl & 0b100) == 0) {
            ppu.v = (ppu.v + 1) & 0x3fff;
          } else {
            ppu.v = (ppu.v + 32) & 0x3fff;
          }
          
          // for debugging...
          if (debugBooleans[2]) {
            ppu.screen.pixels[ppu.dot + ppu.scanline * ppu.screen.width] = color(255, 6, 13);
          }
          break;
  
        default:
          println("Open Bus write to PPU register: " + ((address - 0x2000) & 7));
          break;
      }
    }

    if (address == 0x4014) { // oamDma
      cpu.oamDMA = 256;
      cpu.oamHi = value << 8;
    }

    // controller polling
    if (address == 0x4016) {
      ctrl1Value = value;

      ctrl1Poll = value & 1;

      if (ctrl1Poll == 0) {
        for (int i = 0; i < 8; i ++) {
          boolean buttonPress = (boolean)nesController[i][1];
          if (buttonPress) {
            ctrl1 |= 1 << i;
          } else {
            ctrl1 &= 0b11111111 ^ (1 << i);
          }
        }
      }
    }

    if (address >= 0x8000) {
      switch(mapper) {
      case 1: // MMC1
        mmc1Shift >>= 1;
        mmc1Shift |= (value & 1) << 5;
        
        if ((mmc1Shift & 1) == 1) {
          mmc1Shift >>= 1;
          
          if (address >= 0x8000 && address < 0xA000) { // control
            mmc1Control = mmc1Shift;
            
            switch((mmc1Control & 0b1100) >> 2) {
              case 2:
                currentlySelectedBanks[0] = 0;
                break;
              case 3:
                currentlySelectedBanks[1] = romBanks.length - 1;
                break;
            }
          }
          if (address >= 0xA000 && address < 0xC000) { // CHR bank 0
            if (mmc1Control >> 4 == 1) {
              ppuBus.currentlySelectedBanks[0] = mmc1Shift;
            } else {
              ppuBus.currentlySelectedBanks[0] = mmc1Shift & 0b11110;
              ppuBus.currentlySelectedBanks[1] = (mmc1Shift & 0b11110) + 1;
            }
          }
          if (address >= 0xC000 && address < 0xE000) { // CHR bank 1
            if (mmc1Control >> 4 == 1) {
              ppuBus.currentlySelectedBanks[1] = mmc1Shift;
            } else {
              ppuBus.currentlySelectedBanks[0] = mmc1Shift & 0b11110;
              ppuBus.currentlySelectedBanks[1] = (mmc1Shift & 0b11110) + 1;
            }
          }
          if (address >= 0xE000) { // PRG bank
            switch((mmc1Control & 0b1100) >> 2) {
              case 0:
              case 1:
                currentlySelectedBanks[0] = mmc1Shift & 0b11110;
                currentlySelectedBanks[1] = (mmc1Shift & 0b11110) + 1;
                break;
              case 2:
                currentlySelectedBanks[1] = mmc1Shift;
                break;
              case 3:
                currentlySelectedBanks[0] = mmc1Shift;
                break;
            }
          }
          
          mmc1Shift = 0b100000;
        }
        
        if (value >> 7 == 1) {
          mmc1Control = 0x0C;
          mmc1Shift = 0b100000;
          currentlySelectedBanks[1] = romBanks.length - 1;
        }
        break;
      case 2: // UxROM
        currentlySelectedBanks[0] = value & 0xF;
        break;
      case 3: // CNROM
        ppuBus.currentlySelectedBanks[0] = (value & 3) << 1;
        ppuBus.currentlySelectedBanks[1] = ((value & 3) << 1) + 1;
        break;
      case 7: // AxROM
        currentlySelectedBanks[0] = (value & 0b111) * 2;
        currentlySelectedBanks[1] = (value & 0b111) * 2 + 1;
        ppuBus.vramPageSelect = ((value & 0b10000) >> 4) == 1;
        break;
      }
    }
  }

  int read(int address) { // read a value from the main bus
    if (address < 0x2000) { // ram READ
      openBus = ram[address % 0x800];
      return openBus;
    }
    
    if (address >= 0x6000 & address < 0x8000) { // prg ram READ
      openBus = prgRam[address - 0x6000];
      return openBus;
    }
    
    // apu
    if (address == 0x4015) {
      int apuStatus = 
        (apu.pulse1Counter > 0 ? 1 : 0)
        | (apu.pulse2Counter > 0 ? 2 : 0)
        | 0 // bit 2
        | 0 // bit 3
        | 0 // bit 4
        | (openBus & 32);
        //| (apu.interruptInhibit ? 0b1000000 : 0);
        
      apu.interruptInhibit = false;
      return apuStatus;
    }

    // PPU registers
    if (address >= 0x2000 && address < 0x4000 && !ppu.firstFrame) {
      switch(((address - 0x2000) & 7)) {
      case 2: // PPU STATUS
        ppu.w = false;
        ppuOpenBus = ppu.ppuStatus | (ppuOpenBus & 0b00011111);
        ppu.ppuStatus &= 0b01111111;

        if (ppu.scanline == 241 && ppu.dot == 0) {
          ppuOpenBus &= 0b01111111;
          ppu.suppressVbl = true;
        }
        
        // for debugging...
        if (debugBooleans[2]) {
          ppu.screen.pixels[ppu.dot + ppu.scanline * ppu.screen.width] = color(255, 116, 10);
        }
        openBus = ppuOpenBus;
        return ppuOpenBus;

      case 4: // OAM DATA
        if (ppu.inRender && (ppu.dot >= 1 && ppu.dot <= 64)) {
          ppuOpenBus = 0xFF;
        } else {
          if ((ppu.oamAddr & 2) == 2) {
            ppuOpenBus = ppu.oam[ppu.oamAddr] & 0b11100011;
          } else {
            ppuOpenBus = ppu.oam[ppu.oamAddr];
          }
        }
        
        // for debugging...
        if (debugBooleans[2]) {
          ppu.screen.pixels[ppu.dot + ppu.scanline * ppu.screen.width] = color(253, 255, 179);
        }
        openBus = ppuOpenBus;
        return ppuOpenBus;

      case 7: // PPU DATA
        int ppuDataOldOpenBus = ppuOpenBus & 0b11000000;
        ppuOpenBus = ppuBus.ppuDataReadBuffer;

        ppuBus.ppuDataReadBuffer = ppuBus.read(ppu.v);

        if (ppu.v >= 0x3F00) {
          ppuOpenBus = ppuBus.ppuDataReadBuffer | ppuDataOldOpenBus;
          ppuBus.ppuDataReadBuffer = ppuBus.read(ppu.v - 0x1000);
        }
        
        if ((ppu.bgEnabled || ppu.spEnabled) && ppu.inRender) {
          ppu.incrementY();
        } else {
          if ((ppu.ppuCtrl & 0b100) == 0) {
            ppu.v = (ppu.v + 1) & 0x3FFF;
          } else {
            ppu.v = (ppu.v + 32) & 0x3FFF;
          }
        }
        
        // for debugging...
        if (debugBooleans[2]) {
          ppu.screen.pixels[ppu.dot + ppu.scanline * ppu.screen.width] = color(255, 125, 125);
        }
        openBus = ppuOpenBus;
        return ppuOpenBus;
      default:
        println("Open Bus read from PPU register: " + ((address - 0x2000) & 7));
        openBus = ppuOpenBus;
        
        return ppuOpenBus;
      }
    }

    if (address == 0x4016 && !ppu.firstFrame) {
      if (ctrl1Poll == 0) {
        ctrl1Value = ctrl1 & 1;

        openBus = ctrl1Value | (openBus & 0b11100000);

        ctrl1 = ctrl1 >> 1;
      }
      return openBus;
    }

    if (address >= 0x8000 && address < 0xC000) { // rom READ (lo)
      openBus = romBanks[currentlySelectedBanks[0] % romBanks.length][address - 0x8000];
      return openBus;
    }
    if (address >= 0xC000 && address < 0x10000) { // rom READ (hi)
      openBus = romBanks[currentlySelectedBanks[1] % romBanks.length][address - 0xC000];
      return openBus;
    }

    return openBus; // if the address is "unmapped," return open bus.
  }
}
