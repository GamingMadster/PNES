// function to initialize classes used to emulate the NES hardware
void initClasses() {
  cpuBus = new Ricoh2A03Bus();
  ppuBus = new Ricoh2C02Bus();

  cpu = new newRicoh2A03();
  ppu = new Ricoh2C02();
  
  gui = new LazyGui(this);
  
  guiBuffers = (PGraphics[])append(guiBuffers, createGraphics(256, 64)); // cpu register display
  guiBuffers = (PGraphics[])append(guiBuffers, createGraphics(256, 64)); // ppu register display
  
  for (PGraphics buffer : guiBuffers) {
    buffer.beginDraw();
    buffer.background(0);
    buffer.textSize(16);
    buffer.textAlign(LEFT, TOP);
  }

  // load the palette into the ppu
  byte[] loadedPalette = loadBytes("palettes/2C02G_wiki.pal");

  for (int pal = 0; pal < ppu.PALETTE.length; pal ++) {
    int mul3 = pal * 3;

    ppu.PALETTE[pal] = color(loadedPalette[mul3] & 0xFF, loadedPalette[mul3 + 1] & 0xFF, loadedPalette[mul3 + 2] & 0xFF);
  }
  
  // some stuff to setup the screen buffer
  ppu.screen.beginDraw();
  
  ppu.screen.loadPixels();
  
  setupGui();
}

// gui
void setupGui() {
  gui.pushFolder("emulator");
  
  gui.pushFolder("file"); // file folder
  gui.button("load ROM file (.nes)");
  gui.popFolder();
  
  gui.pushFolder("game"); // game folder
  gui.button("pause \\/ resume");
  gui.button("soft reset");
  gui.button("hard reset");
  gui.popFolder();
  
  gui.pushFolder("debug"); // debug folder
  gui.image("cpu registers", guiBuffers[0]);
  gui.image("ppu registers", guiBuffers[1]);
  
  gui.toggle("view blanking area");
  gui.toggle("show blanking area garbage");
  gui.toggle("view ppu read \\/ writes");
  
  for (int iter = 0; iter < 3; iter ++) debugBooleans = (boolean[])append(debugBooleans, false);
  
  gui.popFolder();
  
  gui.popFolder();
}

void updateGui() {
  gui.pushFolder("emulator");
  
  gui.pushFolder("file"); // file folder
  if (gui.button("load ROM file (.nes)")) {
    selectInput("Select a .NES file to load.", "loadROM");
  }
  gui.popFolder();
  
  gui.pushFolder("game"); // game folder
  if (gui.button("pause \\/ resume")) {
    machineRunning = !machineRunning;
  }
  if (gui.button("soft reset")) {
    cpu.reset();
  }
  gui.button("hard reset");
  gui.popFolder();
  
  // debug
  for (PGraphics buffer : guiBuffers) {
    buffer.beginDraw();
    buffer.background(0);
  }
  
  // cpu registers
  guiBuffers[0].text("A: $" + hex(cpu.a, 2), 4, 2);
  guiBuffers[0].text("X: $" + hex(cpu.x, 2), 4, 18);
  guiBuffers[0].text("Y: $" + hex(cpu.y, 2), 4, 34);
  guiBuffers[0].text("S: $" + hex(cpu.s, 2), 4, 50);
  guiBuffers[0].text("P: b" + String.format("%8s", Integer.toBinaryString(cpu.p)).replaceAll(" ", "0"), 128, 2);
  
  guiBuffers[0].text("PC: $" + hex(cpu.pc, 4), 128, 34);
  guiBuffers[0].text("OP: $" + hex(cpu.opCode, 2), 128, 50);
  
  for (PGraphics buffer : guiBuffers) {
    buffer.endDraw();
  }
  
  gui.pushFolder("debug"); // debug folder
  gui.image("cpu registers", guiBuffers[0]);
  //gui.image("ppu registers", guiBuffers[1]);
  
  debugBooleans[0] = gui.toggle("view blanking area");
  debugBooleans[1] = gui.toggle("show blanking area garbage");
  debugBooleans[2] = gui.toggle("view ppu read \\/ writes");
  gui.popFolder();
  
  gui.popFolder();
}

// cycle hander
void cycleMachine() {
  float cycleRatio = ppu.SPEED / (cpu.SPEED * 2);

  for (float ppuCycles = ppu.ppuOffset; ppuCycles <= ppu.SPEED; ppuCycles += 1) {
    ppu.clock();
    
    if ((cpu.cpuCycles >= cycleRatio)) {
      cpu.cpuCycles %= cycleRatio;

      cpu.clock();
    }

    cpu.cpuCycles += 1;
    ppu.ppuOffset = ppuCycles;
  }

  cpuBus.ppuOpenBus = 0;

  ppu.ppuOffset -= ppu.SPEED;
}

void runFrame() {
  cycleMachine();
  
   //funny ntsc filter trust
   //ppu.screen.updatePixels();
   //PGraphics ntsc = ntscFilter(ppu.screen);
    
   //image(ntsc, 0, 0, ntsc.width * 3, ntsc.height * 3);
}

// rom loading handler
void loadROM(File rom) {
  if (rom != null) {
    // File byte array
    byte[] bytes = loadBytes(rom);

    // Constants
    int PRG_ROM_SIZE = 16384;
    int CHR_ROM_SIZE = 0x1000;
    int PRG_ROM_OFFSET = 16;
    int CHR_ROM_OFFSET = PRG_ROM_SIZE * (int)bytes[4] + PRG_ROM_OFFSET;

    // variables
    int[] prgRomBank = new int[0]; // used as a temporary variable to gather banks
    int[] chrRomBank = new int[0]; // same as prgRomBank

    int prgRomBanks = bytes[4] & 0xFF;
    int chrRomBanks = (bytes[5] & 0xFF) * 2;

    cpuBus.mapper = ((int)(bytes[7] & 0xF0)) | ((int)(bytes[6] >> 4));

    // initialize the bus rom banks
    cpuBus.romBanks = new int[prgRomBanks][0];
    ppuBus.patternTables = new int[chrRomBanks][0];

    // special case for chr ram
    if (chrRomBanks == 0) {
      ppuBus.chrRamUsed = true;
      ppuBus.patternTables = new int[1][0x2000]; // this acts as the "chr ram", as chrRamUsed will allow writes to the pattern table space in memory.
      ppuBus.currentlySelectedBanks[0] = 0;
      ppuBus.currentlySelectedBanks[1] = 0;
    } else {
      ppuBus.chrRamUsed = false;
      ppuBus.currentlySelectedBanks[0] = 0;
      ppuBus.currentlySelectedBanks[1] = 1;
    }

    // nametable mirroring
    ppuBus.nametableMirroring = ((bytes[6] & 1) == 1 ? false : true);

    // chr rom bank setup
    for (int banks = 0; banks < chrRomBanks; banks += 1) {
      chrRomBank = new int[0];

      int offset = banks * CHR_ROM_SIZE;

      for (int bankByte = 0; bankByte < CHR_ROM_SIZE; bankByte += 1) {
        chrRomBank = append(chrRomBank, bytes[bankByte + CHR_ROM_OFFSET + offset] & 0xFF);
      }

      ppuBus.patternTables[banks] = chrRomBank;
    }

    // cpu bank setup
    for (int banks = 0; banks < prgRomBanks; banks += 1) {
      prgRomBank = new int[0];

      int offset = banks * PRG_ROM_SIZE;

      for (int bankByte = 0; bankByte < PRG_ROM_SIZE; bankByte += 1) {
        prgRomBank = append(prgRomBank, bytes[bankByte + PRG_ROM_OFFSET + offset] & 0xFF);
      }

      cpuBus.romBanks[banks] = prgRomBank;
    }

    // make sure the mapper is properly configured
    switch(cpuBus.mapper) {
    case 0: // NROM
      cpuBus.currentlySelectedBanks[0] = 0;
      cpuBus.currentlySelectedBanks[1] = cpuBus.romBanks.length - 1;
      break;
    case 1: // MMC1
    case 2: // UxROM
    case 3: // CNROM
      cpuBus.currentlySelectedBanks[1] = cpuBus.romBanks.length - 1;
      break;
    default:
      cpuBus.currentlySelectedBanks[0] = 0;
      cpuBus.currentlySelectedBanks[1] = cpuBus.romBanks.length - 1;
      break;
    }

    // set the status register and the program counter to their appropriate values
    //cpu.sr = 0b00100100;
    //cpu.pc = (cpuBus.read(0xFFFD) << 8) + cpuBus.read(0xFFFC);

    // set the cycleCount of the cpu to zero
    //cpu.cycleCount = 0;
    
    cpu.reset();

    // ppu setup
    ppu.ppuCtrl = 0;
    ppu.ppuMask = 0;

    ppu.v = 0;
    ppu.t = 0;

    ppu.dot = 25;
    ppu.scanline = 261;

    ppu.firstFrame = true;

    println("-----[ROM INFORMATION]-----");
    println("MAPPER: " + cpuBus.mapper);
    println("PRG ROM Size: " + bytes[4] * PRG_ROM_SIZE + " bytes");
    println("PRG ROM Banks: " + bytes[4]);
    println("Reset Vector: " + hex((cpuBus.read(0xFFFD) << 8) + cpuBus.read(0xFFFC), 4));
  }
}

void keyPressed() {
  //if (key == '1') {
  //  // stop emulation
  //  machineRunning = !machineRunning;
  //}

  //if (key == '2') {
  //  // call a file input to load a rom file
  //  selectInput("Select a .NES file to load.", "loadROM");
  //}

  if (key == '3') {
    ppu.adjDot -= 1;
  }
  
  if (key == '4') {
    ppu.adjDot += 1;
  }

  // controller 1
  for (int i = 0; i<8; i++) {
    Object[] controllerButton = nesController[i];

    if (controllerButton[0].equals(keyCode)) {
      nesController[i][1] = true;
    }
  }
}

void keyReleased() {
  for (int i = 0; i<8; i++) {
    Object[] controllerButton = nesController[i];

    if (controllerButton[0].equals(keyCode)) {
      nesController[i][1] = false;
    }
  }
}

// math stuff
int mathClamp(int val, int min, int max) {
  return Math.min(Math.max(val, min), max);
}
