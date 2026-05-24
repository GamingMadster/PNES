Ricoh2C02 ppu;

class Ricoh2C02 { // NES "Picture Processing Unit"
  // general constants
  float SPEED = 89341.5; // this is cycles that occur every frame (NTSC: 89341.5 cycles per frame at 60hz)

  float ppuOffset = 0;

  // ppu-specific constants
  int RENDER_SCANLINES = 240; // this is the amount of scanlines that occur while the ppu is rendering
  int POST_SCANLINES = 1; // this is the amount of "post-render" scanlines that occur after the rendering phase, but before the blanking phase
  int BLANKING_SCANLINES = 20; // this is the amount of scanlines that occur in the "vertical-blanking" phase

  int DOTS_PER_LINE = 340; // this is how many ppu dots occur per scanline

  color[] PALETTE = new color[512];

  // other information:
  // vblank is set at scanline 241, dot 1, and is automatically cleared on dot 1 of the pre-render scanline.

  boolean dotSkip = false;
  int nextTile = 0;

  // internal registers
  int v = 0;
  int t = 0;
  int x = 0;
  boolean w = false;

  // exposed registers to the cpu bus
  int ppuCtrl = 0;
  int ppuMask = 0;
  int ppuStatus = 0;

  int oamAddr = 0;

  // the screen
  PGraphics screen = createGraphics(341, 262);

  int[] oam = new int[256];

  // other variables to count dots for tile fetching, etc.
  int dot = 0;
  int scanline = 0;

  int fineX = 0;

  int bgPatternByteA, bgPatternByteB = 0;

  boolean suppressVbl = false;
  boolean hitNmi = false;
  boolean firstFrame = true;

  int[] ntBuffer = new int[2];
  int[] atBuffer = new int[2];
  
  int ntShiftRegister = 0;
  int atShiftRegister = 0;
  
  int dotMod = 0;
  
  int coarseX = 0;
  int coarseY = 0;
  int fineY = 0;
  int ntAddress = 0;
  int atAddress = 0;
  
  boolean bgEnabled = false;
  boolean spEnabled = false;
  boolean inRender = false;
  
  int bgMask = 0;
  int spMask = 0;
  int pixelColor = 0;
  
  // sprite stuff
  //int delaySpriteZero = 0;
  int[] spriteCount = new int[0];
  
  int adjDot = 1;

  void clock() { // run a cycle of the PPU
    dot += 1;
    
    //if (delaySpriteZero > 0) {
    //  delaySpriteZero -= 1;
    //  if (delaySpriteZero == 0) ppuStatus |= 0b01000000;
    //}

    // dot and scanline wraparound
    if (dot == DOTS_PER_LINE + 1) {
      spriteCount = new int[0];
      
      dot = 0;
      scanline += 1;

      if (scanline == RENDER_SCANLINES + POST_SCANLINES + BLANKING_SCANLINES + 1) {
        scanline = 0;
        if ((ppuMask & 0b1000) > 0) {
          if (dotSkip) dot += 1;
        }
        
        dotSkip = !dotSkip;
        
        firstFrame = false;
        
        screen.updatePixels();
        
        if (gui.toggle("emulator/debug/view blanking area")) {
          mainDisplay = screen;
        } else {
          mainDisplay = screen.get(1, 0, 256, 240);
        }
        float xRatio = (float)width / mainDisplay.width;
        float yRatio = (float)height / mainDisplay.height;
        float imgRatio = xRatio / yRatio;
        
        if (imgRatio < 1) {
          image(mainDisplay, width / 2, height / 2, width, (float)height * imgRatio);
        } else {
          image(mainDisplay, width / 2, height / 2, (float)width / imgRatio, height);
        }
      }
    }
    
    // logic for vertical blank....
    if (dot == 1 && scanline == 241 && !suppressVbl) ppuStatus |= 0b10000000; 
    if (dot == 1 && scanline == 261) {
      ppuStatus &= 0b00011111;
      
      hitNmi = false;
      suppressVbl = false;
    }
    
    if ((scanline >= 0 && scanline <= 239) || scanline == 261) {
        if (dot >= 257 && dot <= 320) {
          oamAddr = 0;
        }
    }
    
    // logic for fetching...
    dotMod = ((dot - 1) % 8);
    
    // v register scroll variables
    coarseX = v & 0b11111;
    coarseY = (v & 0b1111100000) >> 5;
    
    fineY = v >> 12;
    
    ntAddress = 0x2000 | (v & 0x0FFF);
    atAddress = 0x23C0 | (v & 0x0C00) | ((v >> 4) & 0x38) | ((v >> 2) & 0x07);
    
    bgEnabled = (ppuMask & 0b1000) > 0;
    spEnabled = (ppuMask & 0b10000) > 0;
    
    bgMask = (ppuMask & 0b10) > 0 ? 0 : 8;
    spMask = (ppuMask & 0b100) > 0 ? 0 : 8;
    
    if (bgEnabled || spEnabled) { // is rendering enabled at all? clock shift registers if so
      if ((scanline >= 0 && scanline <= 239) || scanline == 261) {
        if ((dot >= 1 && dot <= 256) || (dot >= 321 && dot <= 336)) {
          inRender = true;
          if (dotMod == 0) {
            ntBuffer = append(ntBuffer, ppuBus.read(ntAddress)); // fetch tile and store to shift reg...
            ntBuffer = subset(ntBuffer, 1);
          }
          
          if (dotMod == 0) {
            atBuffer = append(atBuffer, ppuBus.read(atAddress)); // fetch attribute and store to shift reg...
            atBuffer = subset(atBuffer, 1);
          }
          
          if (dotMod == 7) {
            incrementX();
          }
          
          if (dot == 256) {
            incrementY();
          }
        } else {
          inRender = false;
        }
        
        if (dot == 257) {
          v = (v & ~0b000010000011111) | (t & 0b000010000011111);
        }
        
        if (scanline == 261 && dot >= 280 && dot <= 304) {
          v = (v & ~0b111101111100000) | (t & 0b111101111100000);
        }
        
        if (dot == 257 || dot == 265 || dot == 305) {
          ntBuffer = append(ntBuffer, ppuBus.read(ntAddress)); // fetch tile and store to shift reg...
          ntBuffer = subset(ntBuffer, 1);
        }
        
        int dotModShift = (dotMod + fineX - 1) % 8;
        
        if (dotModShift == 7) {
          ntShiftRegister = ntBuffer[0];
          atShiftRegister = atBuffer[0];
        }
      } else {
        inRender = false;
      }
    }
    
    // logic for background rendering...
    boolean bgOpaque = false; // variable for use in sprite priority and sprite 0 hit
    
    if (bgEnabled) {
      if ((scanline >= 0 && scanline <= 239) || scanline == 261) {
        if ((dot >= 1 && dot <= 256) || (dot >= 321 && dot <= 336)) {
          // selection of the nametable in the buffer (with adjusted dotModShift)
          int dotModShift = (dotMod + fineX) % 8;
          
          // tile logic...
          int tableAddress = (ppuCtrl & 0b10000) > 0 ? 0x1000 : 0;
          
          // tile hi byte and lo byte
          int tileLo = ppuBus.read(tableAddress + ntShiftRegister * 16 + fineY);
          int tileHi = ppuBus.read(tableAddress + ntShiftRegister * 16 + 8 + fineY);
          
          // the real pixel
          int shiftedPixel = (((tileHi >> (7 - dotModShift)) & 1) << 1) | ((tileLo >> (7 - dotModShift)) & 1);
          bgOpaque = shiftedPixel > 0;
          
          // attribute logic...
          int xQuadrant = ((((coarseX << 3) | fineX) + dotMod) & 0b10000) >> 3;
          int yQuadrant = (int)Math.floor((coarseY % 4) / 2) * 4;
          
          int atBits = (atShiftRegister >> (2 - xQuadrant + yQuadrant)) & 3;
          
          int paletteIndex = ppuBus.read(0x3F00 + atBits * 4 + shiftedPixel);
          
          int emphasisBits = ppuMask >> 5 << 6;
          
          if (shiftedPixel == 0 || dot < bgMask + 1) {
            pixelColor = PALETTE[ppuBus.read(0x3F00) + emphasisBits];
          } else {
            pixelColor = PALETTE[paletteIndex + emphasisBits];
          }
          
          screen.pixels[dot + scanline * screen.width] = pixelColor;
          
          if (dotModShift == 7) {
            ntShiftRegister = ntBuffer[0];
            atShiftRegister = atBuffer[0];
          }
        } else {
          if (gui.toggle("emulator/debug/show blanking area garbage")){
            renderBackground();
          } else {
            screen.pixels[dot + scanline * screen.width] = color(128, 128, 128);
          }
        }
      } else {
        if (gui.toggle("emulator/debug/show blanking area garbage")){
          renderBackground();
        } else {
          screen.pixels[dot + scanline * screen.width] = color(128, 128, 128);
        }
      }
    } else {
      if (spEnabled) {
        if ((scanline >= 0 && scanline <= 239) || scanline == 261) {
          if ((dot >= 1 && dot <= 256) || (dot >= 321 && dot <= 336)) {
            int emphasisBits = ppuMask >> 5 << 6;
          
            pixelColor = PALETTE[ppuBus.read(0x3F00) + emphasisBits];
            
            screen.pixels[dot + scanline * screen.width] = pixelColor;
          } else {
            if (gui.toggle("emulator/debug/show blanking area garbage")){
              renderBackground();
            } else {
              screen.pixels[dot + scanline * screen.width] = color(128, 128, 128);
            }
          }
        } else {
          if (gui.toggle("emulator/debug/show blanking area garbage")){
            renderBackground();
          } else {
            screen.pixels[dot + scanline * screen.width] = color(128, 128, 128);
          }
        }
      } else {
        if (gui.toggle("emulator/debug/show blanking area garbage") || ((scanline >= 0 && scanline <= 239) || scanline == 261)){
          if ((dot >= 1 && dot <= 256) || (dot >= 321 && dot <= 336)) {
            renderBackground();
          } else {
            screen.pixels[dot + scanline * screen.width] = color(128, 128, 128);
          }
        } else {
          screen.pixels[dot + scanline * screen.width] = color(128, 128, 128);
        }
      }
    }
    
    // logic for sprite rendering...
    if (spEnabled) {
      if (scanline >= 0 && scanline <= 239) {
        if (dot >= 1 + spMask && dot <= 256) {
          for (int oamIndex = 63; oamIndex >= 0; oamIndex -= 1) {
            int trueIndex = oamIndex * 4;
            
            int y = oam[trueIndex] + 1;
            int tile = oam[trueIndex + 1];
            int attributes = oam[trueIndex + 2];
            int x = oam[trueIndex + 3];
            
            int spriteHeight = (ppuCtrl & 0b00100000) > 0 ? 16 : 8;
            
            if (scanline >= y && scanline < y + spriteHeight) {
              if (dot >= spMask + 1) {
                if (dot - 1 >= x && dot - 1 < x + 8) {
                  // check for if this sprite has been evaluated already
                  boolean evalFound = false;
                  
                  for (int eval = 0; eval < spriteCount.length; eval += 1) {
                    if (spriteCount[eval] == oamIndex) {
                      evalFound = true;
                      break;
                    }
                  }
                  
                  if (!evalFound) spriteCount = append(spriteCount, oamIndex);
                  if (spriteCount.length >= 9) {
                    ppuStatus |= 0b00100000;
                  } else {
                    // x and y offsets for fetching tiles
                    int tileRow = scanline - y;
                    int tileDot = dot - x - 1;
                    
                    int nextTile = 0;
                    
                    // sprite flip
                    int flipX = (attributes & 0b01000000) > 0 ? tileDot : 7 - tileDot;
                    int flipY = (attributes & 0b10000000) > 0 ? 7 - (tileRow % 8) : (tileRow % 8);
                    
                    // tile logic...
                    int tableAddress;
                    
                    if (spriteHeight == 8) {
                      tableAddress = (ppuCtrl & 0b1000) > 0 ? 0x1000 : 0;
                    } else {
                      tableAddress = (tile & 1) > 0 ? 0x1000 : 0;
                      tile &= ~1;
                      nextTile = (attributes & 0b10000000) > 0 ? 1 - (int)Math.floor(tileRow / 8) : (int)Math.floor(tileRow / 8);
                    }
                    
                    // tile hi byte and lo byte
                    int tileLo = ppuBus.read(tableAddress + (tile + nextTile) * 16 + flipY);
                    int tileHi = ppuBus.read(tableAddress + (tile + nextTile) * 16 + 8 + flipY);
                    
                    // the real pixel
                    int shiftedPixel = (((tileHi >> flipX) & 1) << 1) | ((tileLo >> flipX) & 1);
                    
                    int paletteIndex = ppuBus.read(0x3F00 + (attributes & 3) * 4 + shiftedPixel + 16);
                    
                    int emphasisBits = ppuMask >> 5 << 6;
                    int pixelColor = PALETTE[paletteIndex + emphasisBits];
                    
                    if (shiftedPixel > 0) {
                      if (
                        oamIndex == 0
                        && bgOpaque
                        && x <= 254
                        && dot >= bgMask + 1
                        && dot < 256
                      ) ppuStatus |= 0b01000000;
                      
                      if ((attributes & 0b100000) > 0) {
                        if (!bgOpaque) {
                          screen.pixels[dot + scanline * screen.width] = pixelColor;
                        }
                      } else {
                        screen.pixels[dot + scanline * screen.width] = pixelColor;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  
  void incrementX() {
   if ((v & 0x001F) == 31) {
     v &= ~0x001F;
     v ^= 0x0400;
   } else {
     v += 1;
   }
  }
  
  void incrementY() {
    if ((v & 0x7000) != 0x7000) {
      v += 0x1000;
    } else {
      v &= ~0x7000;
      int y = (v & 0x03E0) >> 5;
      if (y == 29) {
        y = 0;
        v ^= 0x0800;
      } else if (y == 31) {
        y = 0;
      } else {
        y += 1;
      }
      v = (v & ~0x03E0) | (y << 5);
    }
  }
  
  void renderBackground() {
    pixelColor = 0;
    
    int emphasisBits = ppuMask >> 5 << 6;
    
    if (v >= 0x3F00) {
      pixelColor = PALETTE[ppuBus.read(v) + emphasisBits];
    } else {
      pixelColor = PALETTE[ppuBus.read(0x3F00) + emphasisBits];
    }
    
    screen.pixels[dot + scanline * screen.width] = pixelColor;
  }
}
