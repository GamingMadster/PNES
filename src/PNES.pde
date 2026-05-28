import processing.sound.*;
import com.krab.lazy.*;

boolean machineRunning = false;

LazyGui gui;
PGraphics[] guiBuffers = new PGraphics[0];

PImage mainDisplay;

PFont mono;

void setup() {
  // setup the window
  size(1280, 720, P2D);
  surface.setResizable(true);
  
  mono = createFont("JetBrains.ttf", 14);
  
  ((PGraphicsOpenGL)g).textureSampling(3);
  imageMode(CENTER);

  // call function to initialize the classes
  initClasses();
}

void draw() {
  background(gui.colorPicker("options/themes/sketch background").hex);
  
  windowTitle("PNES - FPS: " + (double)Math.round(frameRate * 100) / 100);

  // the main loop
  if (cpuBus.romBanks != null && machineRunning) {
    runFrame();
  } else {
    apu.pulse1.amp(0);
    apu.pulse2.amp(0);
    apu.triangle.amp(0);
    
    if (gui.toggle("emulator/debug/view blanking area")) {
      mainDisplay = ppu.screen.get();
    } else {
      mainDisplay = ppu.screen.get(1, 0, 256, 240);
    }
    float xRatio = (float)width / mainDisplay.width;
    float yRatio = (float)height / mainDisplay.height;
    float imgRatio = xRatio / yRatio;
    
    mainDisplay.filter(GRAY);
    
    if (imgRatio < 1) {
      image(mainDisplay, width / 2, height / 2, width, (float)height * imgRatio);
    } else {
      image(mainDisplay, width / 2, height / 2, (float)width / imgRatio, height);
    }
  }
  
  updateGui();
}
