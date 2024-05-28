import processing.sound.*;

PFont font;

NES6502 cpu;
NESPPU ppu;
NESAPU apu;

boolean debug = false;

// for debugging
Object[][][] ops = {
  {{"BRK", "IMPL", }, {"ORA", "INDX", }, {"JAM", "IMPL", }, {"SLO", "INDX", }, {"NOP", "ZPG", }, {"ORA", "ZPG", }, {"ASL", "ZPG", }, {"SLO", "ZPG", }, {"PHP", "IMPL", }, {"ORA", "IMM", }, {"ASL", "A", }, {"SLO", "ZPG", }, {"NOP", "ABS"}, {"ORA", "ABS", }, {"ASL", "ABS", }, {"SLO", "ABS", }, },
  {{"BPL", "REL", }, {"ORA", "INDY", }, {"JAM", "IMPL", }, {"SLO", "INDY", }, {"NOP", "ZPGX", }, {"ORA", "ZPGX", }, {"ASL", "ZPGX", }, {"SLO", "ZPGX", }, {"CLC", "IMPL", }, {"ORA", "ABSY", }, {"NOP", "IMPL", }, {"SLO", "ABSY", }, {"NOP", "ABSX", }, {"ORA", "ABSX", }, {"ASL", "ABSX", }, {"SLO", "ABSX", }, },
  {{"JSR", "ABS", }, {"AND", "INDX", }, {"JAM", "IMPL", }, {"RLA", "INDX", }, {"BIT", "ZPG", }, {"AND", "ZPG", }, {"ROL", "ZPG", }, {"RLA", "ZPG", }, {"PLP", "IMPL", }, {"AND", "IMM", }, {"ROL", "A", }, {}, {"BIT", "ABS", }, {"AND", "ABS", }, {"ROL", "ABS"}, {}, },
  {{"BMI", "REL", }, {"AND", "INDY", }, {"JAM", "IMPL", }, {"RLA", "INDY", }, {"NOP", "ZPGX", }, {"AND", "ZPGX", }, {"ROL", "ZPGX", }, {"RLA", "ZPGX", }, {"SEC", "IMPL", }, {"AND", "ABSY", }, {"NOP", "IMPL", }, {}, {}, {"AND", "ABSX", }, {"ROL", "ABSX"}, {}, },
  {{"RTI", "IMPL", }, {"EOR", "INDX", }, {"JAM", "IMPL", }, {"SRE", "INDX", }, {"NOP", "ZPG", }, {"EOR", "ZPG", }, {"LSR", "ZPG", }, {"SRE", "ZPG", }, {"PHA", "IMPL", }, {"EOR", "IMM", }, {"LSR", "A", }, {}, {"JMP", "ABS", }, {"EOR", "ABS", }, {"LSR", "ABS", }, {}, },
  {{"BVC", "REL", }, {"EOR", "INDY", }, {"JAM", "IMPL", }, {"SRE", "INDY", }, {"NOP", "ZPGX", }, {"EOR", "ZPGX", }, {"LSR", "ZPGX", }, {"SRE", "ZPGX", }, {"CLI", "IMPL", }, {"EOR", "ABSY", }, {"NOP", "IMPL", }, {}, {}, {"EOR", "ABSX", }, {"LSR", "ABSX", }, {}, },
  {{"RTS", "IMPL", }, {"ADC", "INDX", }, {"JAM", "IMPL", }, {"RRA", "INDX", }, {"NOP", "ZPG", }, {"ADC", "ZPG", }, {"ROR", "ZPG", }, {"RRA", "ZPG", }, {"PLA", "IMPL", }, {"ADC", "IMM", }, {"ROR", "A", }, {}, {"JMP", "IND", }, {"ADC", "ABS", }, {"ROR", "ABS"}, {}, },
  {{"BVS", "REL", }, {"ADC", "INDY", }, {"JAM", "IMPL", }, {"RRA", "INDY", }, {"NOP", "ZPGX", }, {"ADC", "ZPGX", }, {"ROR", "ZPGX", }, {"RRA", "ZPGX", }, {"SEI", "IMPL", }, {"ADC", "ABSY", }, {"NOP", "IMPL", }, {}, {}, {"ADC", "ABSX", }, {"ROR", "ABSX"}, {}, },
  {{"NOP", "IMM", }, {"STA", "INDX", }, {"NOP", "IMM", }, {"SAX", "INDX", }, {"STY", "ZPG", }, {"STA", "ZPG", }, {"STX", "ZPG", }, {"SAX", "ZPG", }, {"DEY", "IMPL", }, {"NOP", "IMM", }, {"TXA", "IMPL", }, {"ANE", "IMM", }, {"STY", "ABS", }, {"STA", "ABS", }, {"STX", "ABS", }, {"SAX", "ABS", }, },
  {{"BCC", "REL", }, {"STA", "INDY", }, {"JAM", "IMPL", }, {"SHA", "INDY", }, {"STY", "ZPGX", }, {"STA", "ZPGX", }, {"STX", "ZPGY", }, {"SAX", "ZPGY", }, {"TYA", "IMPL", }, {"STA", "ABSY", }, {"TXS", "IMPL", }, {}, {}, {"STA", "ABSX"}, {}, {"SHA", "ABSY", }, },
  {{"LDY", "IMM", }, {"LDA", "INDX", }, {"LDX", "IMM", }, {"LAX", "INDX", }, {"LDY", "ZPG", }, {"LDA", "ZPG", }, {"LDX", "ZPG", }, {"LAX", "ZPG", }, {"TAY", "IMPL", }, {"LDA", "IMM", }, {"TAX", "IMPL"}, {}, {"LDY", "ABS", }, {"LDA", "ABS", }, {"LDX", "ABS", }, {}, },
  {{"BCS", "REL", }, {"LDA", "INDY", }, {"JAM", "IMPL", }, {"LAX", "INDY", }, {"LDY", "ZPGX", }, {"LDA", "ZPGX", }, {"LDX", "ZPGY", }, {"LAX", "ZPGY", }, {"CLV", "IMPL", }, {"LDA", "ABSY", }, {"TSX", "IMPL"}, {}, {"LDY", "ABSX", }, {"LDA", "ABSX", }, {"LDX", "ABSY", }, {}, },
  {{"CPY", "IMM", }, {"CMP", "INDX", }, {"NOP", "IMM", }, {"DCP", "INDX", }, {"CPY", "ZPG", }, {"CMP", "ZPG", }, {"DEC", "ZPG", }, {"DCP", "ZPG", }, {"INY", "IMPL", }, {"CMP", "IMM", }, {"DEX", "IMPL", }, {}, {"CPY", "ABS", }, {"CMP", "ABS", }, {"DEC", "ABS", }, {}, },
  {{"BNE", "REL", }, {"CMP", "INDY", }, {"JAM", "IMPL", }, {"DCP", "INDY", }, {"NOP", "ZPGX", }, {"CMP", "ZPGX", }, {"DEC", "ZPGX", }, {"DCP", "ZPGX", }, {"CLD", "IMPL", }, {"CMP", "ABSY", }, {}, {}, {}, {"CMP", "ABSX"}, {"DEC", "ABSX", }, {}, },
  {{"CPX", "IMM", }, {"SBC", "INDX", }, {"NOP", "IMM", }, {"ISC", "INDX", }, {"CPX", "ZPG", }, {"SBC", "ZPG", }, {"INC", "ZPG", }, {"ISC", "ZPG", }, {"INX", "IMPL", }, {"SBC", "IMM", }, {"NOP", "IMPL", }, {}, {"CPX", "ABS", }, {"SBC", "ABS", }, {"INC", "ABS"}, {}, },
  {{"BEQ", "REL", }, {"SBC", "INDY", }, {"JAM", "IMPL", }, {"ISC", "INDY", }, {"NOP", "ZPGX", }, {"SBC", "ZPGX", }, {"INC", "ZPGX", }, {"ISC", "ZPGX", }, {"SED", "IMPL", }, {"SBC", "ABSY", }, {"NOP", "IMPL"}, {}, {}, {"SBC", "ABSX"}, {"INC", "ABSX", }, {}, },
};

Object[][] nesctrl = {
  {88, false},
  {90, false},
  {32, false},
  {10, false},
  {38, false},
  {40, false},
  {37, false},
  {39, false},
};

int[] apulength = {
  10,
  254,
  20,
  2,
  40,
  4,
  80,
  6,
  160,
  8,
  60,
  10,
  14,
  12,
  26,
  14,
  12,
  16,
  24,
  18,
  48,
  20,
  96,
  22,
  192,
  24,
  72,
  26,
  16,
  28,
  32,
  30,
};

float[] dutytable = {
  0.125,
  0.25,
  0.5,
  0.6235,
};

// contains the busses, counters, and registers
class NES6502 {
  // Mapper-Specific
  int[][] banks = {};

  int banksel = 0;

  // Bus
  int[] bus = new int[0x10000];

  int delay = 0;

  // Counters
  int pc = 0x8000;
  int s = 0xff;

  // Registers
  int a = 0;
  int x = 0;
  int y = 0;
  int status = 0;

  // simple toggle
  boolean running = false;

  // controller
  int ctrl1 = 0;
  int ctrl1poll = 0;
}

// contains ppu registers and display
class NESPPU {
  int[] bus = new int[0x10000];
  int[] oam = new int[0x100];
  color[] palette = new color[64];

  // registers
  boolean wl = false;

  boolean horiz = false;

  int slX = -1;
  int slY = -1;

  int scX = 0;
  int scY = 0;

  int NT = 0;
  int AT = 0;

  int addr = 0;
  int oamaddr = 0;
  
  boolean nmi = false;

  int sprcount = 0;
  
  int datab = 0;

  // display
  PGraphics display = createGraphics(256, 240);

  //debug
  PGraphics nt1 = createGraphics(256, 240);
  PGraphics nt2 = createGraphics(256, 240);
  PGraphics nt3 = createGraphics(256, 240);
  PGraphics nt4 = createGraphics(256, 240);
}

class NESAPU {
  Pulse pulse1;
  Pulse pulse2;
  TriOsc triangle;
  WhiteNoise noise;

  int lc1 = 0;
  int lc2 = 0;
  int lc3 = 0;
  int lc4 = 0;

  int timer1 = 1;
  int timer2 = 1;
  int timer3 = 1;
}

void keyPressed() {
  if (key=='p') {
    if (ppu.slX%3==0)nextcycle();

    ppu.slX++;
    if (ppu.slX>339) {
      ppu.slX = -1;

      ppu.slY ++;
      if (ppu.slY==240)cpu.bus[0x2002] |= 0b10000000;
      if (ppu.slY==260) {
        ppu.slY = -1;
        cpu.bus[0x2002] &= 0b01111111;
      }
    }

    cpu.delay += 0;
  }

  if (key=='o') {
    cpu.running = !cpu.running;
  }
  
  if (key=='i') {
    cpu.running = false;
    selectInput("Select a .NES file to load.", "loadROM");
  }
  
  if (key=='u') {
    debug = !debug;
    
    if(debug){
      surface.setSize(1130, 480);
    }else{
      surface.setSize(1024, 1032);
    }
  }

  for (int i = 0; i<8; i++) {
    Object[] ctrlbutton = nesctrl[i];

    if (ctrlbutton[0].equals(keyCode)) {
      nesctrl[i][1] = true;
    }
  }
}

void keyReleased() {
  for (int i = 0; i<8; i++) {
    Object[] ctrlbutton = nesctrl[i];

    if (ctrlbutton[0].equals(keyCode)) {
      nesctrl[i][1] = false;
    }
  }
}

void setup() {
  // create the canvas
  size(1024, 1032, P2D);

  noStroke();
  ((PGraphicsOpenGL)g).textureSampling(3);

  // fonts
  font = createFont("MinecraftBold-nMK1.otf", 64, true);
  textFont(font);
  textSize(16);

  // define nes classes
  cpu = new NES6502();
  ppu = new NESPPU();
  apu = new NESAPU();

  // apu stuff
  apu.pulse1 = new Pulse(this);
  apu.pulse1.play();

  apu.pulse2 = new Pulse(this);
  apu.pulse2.play();

  apu.triangle = new TriOsc(this);
  apu.triangle.play();
  
  apu.noise = new WhiteNoise(this);
  apu.noise.play();

  // load palette into color array
  byte[] b = loadBytes("composite.pal");

  for (int i = 0; i<b.length; i+=3) {
    ppu.palette[(int)Math.floor(i/3)] = color(b[i]&0xFF, b[i+1]&0xFF, b[i+2]&0xFF);
  }

  ppu.display.beginDraw();
  ppu.display.background(ppu.palette[0]);
  ppu.display.endDraw();

  // load rom
  
  selectInput("Select a .NES file to load.", "loadROM");
  
  ppu.nt1.beginDraw();
  ppu.nt2.beginDraw();
  ppu.nt3.beginDraw();
  ppu.nt4.beginDraw();
  ppu.display.beginDraw();
  
  
}

void draw() {
  background(0);
  
  ppu.display.loadPixels();
  
  ppu.nt1.loadPixels();
  ppu.nt2.loadPixels();
  ppu.nt3.loadPixels();
  ppu.nt4.loadPixels();

  // cycle loop

  //ppu cycle rate - 89343
  //cpu cycle rate - 29781
  
  IntList sprrender = new IntList();

  if (cpu.running) {
    for (int i = 0; i<89489; i++) {
      
      //CPU
      if (i%3==0)nextcycle();

      // PPU
      ppu.slX++;
      if (ppu.slX>339) {
        if(ppu.slY%2==0){
          ppu.slX = 0;
        }else{
          ppu.slX = -1;
        }
        ppu.slY ++;
        sprrender = new IntList();
        if (ppu.slY==240) {
          cpu.bus[0x2002] |= 0b10000000;
        }
        if (ppu.slY==260) {
          ppu.slY = -1;
        }
      }
      
      if(ppu.slY==-1&&ppu.slX==0){
        cpu.bus[0x2002] &= 0b00011111;
        ppu.nmi = false;
      }
      
      if((cpu.bus[0x2002]>>7)==1){
        if ((cpu.bus[0x2000]>>7)==1 && ppu.nmi == false) {
            ppu.nmi = true;
          
            stackwrite(cpu.pc>>8);
            stackwrite(cpu.pc&0xFF);

            stackwrite(cpu.status);

            cpu.pc = (cpu.bus[0xFFFB]<<8)+(cpu.bus[0xFFFA]);
          }
      }

      if (ppu.slY>-1&&ppu.slY<239) {
        if (ppu.slX>-1&&ppu.slX<256) {
          int basent = 0x2000 + 0x400*(cpu.bus[0x2000]&0b11);
          int baseatt = 0x23c0 + 0x400*(cpu.bus[0x2000]&0b11);

          int ppux = floor(((ppu.slX + ppu.scX) % 256) / 8) + floor((ppu.scX + (ppu.slX) % 256) / 256) * 0x400;
          int ppuy = (floor(((ppu.slY + ppu.scY) % 240) / 8) * 32) + floor((ppu.scY + (ppu.slY % 240)) / 240) * 0x800;
          int attx = floor(((ppu.slX  +ppu.scX) % 256) / 32) + floor((ppu.scX + (ppu.slX % 256)) / 256) * 0x400;
          int atty = (floor(((ppu.slY + ppu.scY) % 240) / 32) * 8) + floor((ppu.scY + (ppu.slY % 240)) / 256) * 0x800;

          int ppuaddr = ((((basent + ppux + ppuy) - 0x2000) % 0x1000) + 0x2000);
          
          int attribute = (ppu.bus[(((baseatt + attx + atty) - 0x23c0) % 0x1000) + 0x23c0] >> ((floor((ppu.slX+ppu.scX)/16)%2)*2)+(floor((ppu.slY+ppu.scY+16*floor((ppu.scY+(ppu.slY%240))/256))/16)%2)*4) & 0b11;

          //if(ppu.slX%8==0)ppu.NT = ppu.bus[ppuaddr];
          //if(ppu.slX%16==0)ppu.AT = attribute;
          int addr = ppu.bus[ppuaddr];
          int tile;
          int pal = attribute;

          if (((cpu.bus[0x2000]>>4)&0x1)==1) {
            tile = ((ppu.bus[addr*16 + ((ppu.slY+ppu.scY) % 8) + 0x1000] >> (7 - ((ppu.slX+ppu.scX) % 8))) & 0x1) + ((ppu.bus[addr*16 + ((ppu.slY+ppu.scY) % 8) + 0x1000 + 8] >> (7 - ((ppu.slX+ppu.scX) % 8))) & 0x1) * 2;
          } else {
            tile = ((ppu.bus[addr*16 + ((ppu.slY+ppu.scY) % 8)] >> (7 - ((ppu.slX+ppu.scX) % 8))) & 0x1) + ((ppu.bus[addr*16 + ((ppu.slY+ppu.scY) % 8) + 8] >> (7 - ((ppu.slX+ppu.scX) % 8))) & 0x1) * 2;
          }

          int pixel = ppu.palette[ppu.bus[0x3f00 + pal*4 + tile]];

          int ppos = (ppu.slX+ppu.slY*256)%ppu.display.pixels.length;

          if ((cpu.bus[0x2001]&0x8)>0) {
            if (tile==0) {
              ppu.display.pixels[ppos] = ppu.palette[ppu.bus[0x3f00]];
            } else {
              ppu.display.pixels[ppos] = pixel;
            }
          } else {
            ppu.display.pixels[ppos] = ppu.palette[ppu.bus[0x3f00]];
          }

          // sprites
          for (int o = 0; o<256; o+=4) {
            if (ppu.slY>=(ppu.oam[o]+1)&&ppu.slY<(ppu.oam[o]+9+8*(((cpu.bus[0x2000]>>5)&0x1)))) {
              if (ppu.slX>=ppu.oam[o+3]&&ppu.slX<(ppu.oam[o+3]+8)) {
                if(sprrender.size()<=8){
                  if(!sprrender.hasValue(o)){
                    sprrender.append(o);
                  }
                  drawSprites(o, ((ppu.oam[o+2]>>5)&0x1));
                }else{
                  cpu.bus[0x2002] |= 0b100000;
                }
              }
            }
          }
        }
      }
    }
  }

  if (cpu.bus[0x4001]>>7==1) {
    if ((cpu.bus[0x4001]&0b1000)>0) {
      apu.timer1 += -(apu.timer1>>((cpu.bus[0x4001]>>4)&0b111)) - 1;
    } else {
      apu.timer1 += apu.timer1>>((cpu.bus[0x4001]>>4)&0b111);
    }
  }
  if (cpu.bus[0x4005]>>7==1) {
    if ((cpu.bus[0x4005]&0b1000)>0) {
      apu.timer2 += -(apu.timer2>>((cpu.bus[0x4005]>>4)&0b111)) - 1;
    } else {
      apu.timer2 += apu.timer2>>((cpu.bus[0x4005]>>4)&0b111);
    }
  }
  
  apu.pulse1.width(dutytable[cpu.bus[0x4000]>>6]);
  apu.pulse2.width(dutytable[cpu.bus[0x4004]>>6]);

  float pulse1freq = 1789772.66667/(16*apu.timer1+1);
  float pulse2freq = 1789772.66667/(16*apu.timer2+1);
  float trianglefreq = 1789772.66667/(16*apu.timer3+1);

  apu.pulse1.freq(pulse1freq);
  apu.pulse2.freq(pulse2freq);
  apu.triangle.freq(trianglefreq);

  if((cpu.bus[0x4000]&0xF)>0&&cpu.running){
    apu.pulse1.amp(((float)(cpu.bus[0x4000]&0xF))/32+0.2);
  }else{
    apu.pulse1.amp(0);
  }
  if((cpu.bus[0x4004]&0xF)>0&&cpu.running){
    apu.pulse2.amp(((float)(cpu.bus[0x4004]&0xF))/32+0.15);
  }else{
    apu.pulse2.amp(0);
  }
  if((cpu.bus[0x400C]&0xF)>0&&cpu.running){
    apu.noise.amp(((float)(cpu.bus[0x400C]&0xF))/16+1.2);
  }else{
    apu.noise.amp(0);
  }
  if(cpu.running){
    apu.triangle.amp(0.8);
  }else{
    apu.triangle.amp(0);
  }

  if ((cpu.bus[0x4015]&0x1)==0) {
    apu.pulse1.amp(0);
    apu.lc1 = 0;
    cpu.bus[0x4000] |= 1<<5;
  }
  if ((cpu.bus[0x4015]&0x2)==0) {
    apu.pulse2.amp(0);
    apu.lc2 = 0;
    cpu.bus[0x4004] |= 1<<5;
  }
  if ((cpu.bus[0x4015]&0x3)==0) {
    apu.triangle.amp(0);
    apu.lc3 = 0;
    cpu.bus[0x4008] |= 1<<7;
  }
  if ((cpu.bus[0x4015]&0x4)==0) {
    apu.noise.amp(0);
    apu.lc4 = 0;
    cpu.bus[0x400C] |= 1<<5;
  }

  if (apu.lc1>0) {
    if (((cpu.bus[0x4000]>>5)&0x1)==0)apu.lc1-=1;
  } else {
    apu.pulse1.amp(0);
  }

  if (apu.lc2>0) {
    if (((cpu.bus[0x4004]>>5)&0x1)==0)apu.lc2-=1;
  } else {
    apu.pulse2.amp(0);
  }

  if (apu.lc3>0) {
    if ((cpu.bus[0x4008]>>7)==0)apu.lc3-=1;
  } else {
    apu.triangle.amp(0);
  }
  
  if (apu.lc4>0) {
    if ((cpu.bus[0x400C]>>5)==0)apu.lc4-=1;
  } else {
    apu.noise.amp(0);
  }
  
  //apu.pulse1.amp(0);
  //apu.pulse2.amp(0);
  //apu.triangle.amp(0);

  ppu.display.updatePixels();

  for (int i = 0; i<240; i++) {
    for (int o = 0; o<256; o++) {
      int adr = (ppu.bus[0x2000+(int)(Math.floor(o/8)+Math.floor(i/8)*32)]);

      int tile;
      if (((cpu.bus[0x2000]>>4)&0x1)==1) {
        tile = ((ppu.bus[adr * 16 + (i % 8) + 0x1000] >> (7 - (o % 8))) & 1) + ((ppu.bus[adr * 16 + (i % 8) + 8 + 0x1000] >> (7 - (o % 8))) & 1) * 2;
      } else {
        tile = ((ppu.bus[adr * 16 + (i % 8)] >> (7 - (o % 8))) & 1) + ((ppu.bus[adr * 16 + (i % 8) + 8] >> (7 - (o % 8))) & 1) * 2;
      }

      int pixel = ppu.bus[0x3F00+tile];

      ppu.nt1.pixels[o+i*256] = ppu.palette[pixel];
    }
  }
  
  for (int i = 0; i<240; i++) {
    for (int o = 0; o<256; o++) {
      int adr = (ppu.bus[0x2400+(int)(Math.floor(o/8)+Math.floor(i/8)*32)]);

      int tile;
      if (((cpu.bus[0x2000]>>4)&0x1)==1) {
        tile = ((ppu.bus[adr * 16 + (i % 8) + 0x1000] >> (7 - (o % 8))) & 1) + ((ppu.bus[adr * 16 + (i % 8) + 8 + 0x1000] >> (7 - (o % 8))) & 1) * 2;
      } else {
        tile = ((ppu.bus[adr * 16 + (i % 8)] >> (7 - (o % 8))) & 1) + ((ppu.bus[adr * 16 + (i % 8) + 8] >> (7 - (o % 8))) & 1) * 2;
      }

      int pixel = ppu.bus[0x3F00+tile];

      ppu.nt2.pixels[o+i*256] = ppu.palette[pixel];
    }
  }
  
  for (int i = 0; i<240; i++) {
    for (int o = 0; o<256; o++) {
      int adr = (ppu.bus[0x2800+(int)(Math.floor(o/8)+Math.floor(i/8)*32)]);

      int tile;
      if (((cpu.bus[0x2000]>>4)&0x1)==1) {
        tile = ((ppu.bus[adr * 16 + (i % 8) + 0x1000] >> (7 - (o % 8))) & 1) + ((ppu.bus[adr * 16 + (i % 8) + 8 + 0x1000] >> (7 - (o % 8))) & 1) * 2;
      } else {
        tile = ((ppu.bus[adr * 16 + (i % 8)] >> (7 - (o % 8))) & 1) + ((ppu.bus[adr * 16 + (i % 8) + 8] >> (7 - (o % 8))) & 1) * 2;
      }

      int pixel = ppu.bus[0x3F00+tile];

      ppu.nt3.pixels[o+i*256] = ppu.palette[pixel];
    }
  }
  
  for (int i = 0; i<240; i++) {
    for (int o = 0; o<256; o++) {
      int adr = (ppu.bus[0x2C00+(int)(Math.floor(o/8)+Math.floor(i/8)*32)]);

      int tile;
      if (((cpu.bus[0x2000]>>4)&0x1)==1) {
        tile = ((ppu.bus[adr * 16 + (i % 8) + 0x1000] >> (7 - (o % 8))) & 1) + ((ppu.bus[adr * 16 + (i % 8) + 8 + 0x1000] >> (7 - (o % 8))) & 1) * 2;
      } else {
        tile = ((ppu.bus[adr * 16 + (i % 8)] >> (7 - (o % 8))) & 1) + ((ppu.bus[adr * 16 + (i % 8) + 8] >> (7 - (o % 8))) & 1) * 2;
      }

      int pixel = ppu.bus[0x3F00+tile];

      ppu.nt4.pixels[o+i*256] = ppu.palette[pixel];
    }
  }

  ppu.nt1.updatePixels();
  ppu.nt2.updatePixels();
  ppu.nt3.updatePixels();
  ppu.nt4.updatePixels();

  if(debug){
    image(ppu.display, 0, 0, 512, 480);
  
    fill(255);
    textSize(32);
    if(!cpu.running)text("PAUSED",4,26);
    textSize(16);
  
    // debug
    fill(color(50, 0, 100));
    rect(512, 0, 618, 480);
  
    //858,0,256,240
    image(ppu.nt1, 858, 64, 128, 120);
    image(ppu.nt2, 986, 64, 128, 120);
    image(ppu.nt3, 858, 184, 128, 120);
    image(ppu.nt4, 986, 184, 128, 120);
  
    fill(color(25, 0, 50));
    rect(524, 71, 318, 362);
  
    fill(color(100, 100, 0));
    rect(524, 71, 318, 12);
  
    fill(255);
  
    text("STATUS - ", 512, 12);
  
    fill(cpu.status&0b10000000);
    text("N", 600, 12);
    fill((cpu.status&0b1000000)<<1);
    text("V", 614, 12);
    fill((cpu.status&0b100000)<<2);
    text("U", 628, 12);
    fill((cpu.status&0b10000)<<3);
    text("B", 642, 12);
    fill((cpu.status&0b1000)<<4);
    text("D", 656, 12);
    fill((cpu.status&0b100)<<5);
    text("I", 670, 12);
    fill((cpu.status&0b10)<<6);
    text("Z", 681, 12);
    fill((cpu.status&0b1)<<7);
    text("C", 695, 12);
  
    fill(255);
  
    text("PC - $"+hex(cpu.pc, 4), 512, 24);
    text("A - $"+hex(cpu.a, 2), 512, 36);
    text("X - $"+hex(cpu.x, 2), 512, 48);
    text("Y - $"+hex(cpu.y, 2), 512, 60);
  
    text("SLX - "+ppu.slX, 640, 24);
    text("SLY - "+ppu.slY, 640, 36);
  
    text("PPU ADDR - $"+hex(ppu.addr, 4), 768, 24);
    
    text("I - Load New Rom    O - Pause/Unpause Emulator",520,448);
    text("P - Step Into Next Cycle    U - Debug Toggle",520,464);
    
    for (int i = cpu.pc; i<cpu.pc+26; i++) {
      Object[][] row = ops[cpu.bus[i&0xFFFF]>>4];
  
      Object[] op = row[cpu.bus[i&0xFFFF]&0xF];
  
      String inst;
      String addrM;
  
      String value = "";
  
      if (op.length>0) {
        inst = (String)op[0];
        addrM = (String)op[1];
  
        switch(addrM) {
        case "IMM":
          value = hex(cpu.bus[(i+1)&0xFFFF], 2);
          break;
  
        case "ZPG":
          value = hex(cpu.bus[(i+1)&0xFFFF], 2);
          break;
  
        case "ZPGX":
          value = hex(cpu.bus[(i+1+cpu.x)&0xFFFF], 2);
          break;
  
        case "ZPGY":
          value = hex(cpu.bus[(i+1+cpu.y)&0xFFFF], 2);
          break;
  
        case "ABS":
          value = hex((cpu.bus[(i+2)&0xFFFF]<<8)+cpu.bus[(i+1)&0xFFFF], 4);
          break;
  
        case "ABSX":
          value = hex((cpu.bus[(i+2+cpu.x)&0xFFFF]<<8)+cpu.bus[(i+1+cpu.x)&0xFFFF], 4);
          break;
  
        case "ABSY":
          value = hex((cpu.bus[(i+2+cpu.y)&0xFFFF]<<8)+cpu.bus[(i+1+cpu.y)&0xFFFF], 4);
          break;
  
        case "REL":
          value = hex(i+2 + (cpu.bus[i+1]<<24>>24), 4);
          break;
        }
      } else {
        inst = "???";
        addrM = "???";
      }
  
      if (value!="") {
        value = ", ($"+value+")";
      }
  
      text("$"+hex(i&0xFFFF, 4)+" - $"+hex(cpu.bus[i&0xFFFF], 2)+" - "+inst+", "+addrM+value, 536, 264+(i-cpu.pc-13)*14);
    }
  }else{
    image(ppu.display, 0, 0, 1024, 960);
    
    fill(255);
    textSize(64);
    if(!cpu.running)text("PAUSED",4,46);
    textSize(32);
    
    text("I - Load New Rom    O - Pause/Unpause Emulator",0,984);
    text("P - Step Into Next Cycle    U - Debug Toggle",0,1016);
  }

  windowTitle("PNES - FPS: "+frameRate);
}

void nextcycle() {
  // status flags - NV1B DIZC

  if (cpu.delay>0) {
    cpu.delay-=1;
    return;
  }

  int v;
  int old;
  int oper;
  int signed;
  int b0;

  int op = cpu.bus[cpu.pc];
  cpu.pc++;

  switch(op) {
    // BRK
  case 0x00:
    cpu.pc-=1;
    break;

    //NOP
  case 0xEA:
    cpu.delay += 2;
    break;
  case 0x1A:
    cpu.delay += 2;
    break;
  case 0x3A:
    cpu.delay += 2;
    break;
  case 0x5A:
    cpu.delay += 2;
    break;
  case 0x7A:
    cpu.delay += 2;
    break;
  case 0xDA:
    cpu.delay += 2;
    break;
  case 0xFA:
    cpu.delay += 2;
    break;
  case 0x04:
    addrMode("ZPG");
    cpu.delay += 3;
    break;
  case 0x44:
    addrMode("ZPG");
    cpu.delay += 3;
    break;
  case 0x64:
    addrMode("ZPG");
    cpu.delay += 3;
    break;

    // JMP
  case 0x4C:
    v = addrMode("ABS");
    cpu.pc = v;
    cpu.delay += 3;
    break;
  case 0x6C:
    v = addrMode("IND");
    cpu.pc = v;
    cpu.delay += 5;
    break;

    // JSR
  case 0x20:
    v = addrMode("IMM");

    stackwrite((cpu.pc >> 8) & 0xFF);
    stackwrite((cpu.pc) & 0xFF);

    v += addrMode("IMM")<<8;
    cpu.pc = v;

    cpu.delay += 6;
    break;

    // RTS
  case 0x60:
    v = stackread();
    cpu.pc = v;
    v = stackread();
    cpu.pc += v<<8;
    cpu.pc=(cpu.pc+1)&0xFFFF;

    cpu.delay += 6;
    break;

    // RTI
  case 0x40:
    v = stackread();
    cpu.status = v;
    cpu.status |= 0b00100000;
    cpu.status &= 0b11101111;
    v = stackread();
    cpu.pc = v;
    v = stackread();
    cpu.pc |= v<<8;

    cpu.delay += 6;
    break;

    // LDY
  case 0xA0:
    v = addrMode("IMM");
    cpu.y = v;

    if (cpu.y >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.y == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 2;
    break;
  case 0xA4:
    v = cpuread(addrMode("ZPG"));
    cpu.y = v;

    if (cpu.y >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.y == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 3;
    break;
  case 0xB4:
    v = cpuread(addrMode("ZPGX"));
    cpu.y = v;

    if (cpu.y >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.y == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;
  case 0xAC:
    v = cpuread(addrMode("ABS"));
    cpu.y = v;

    if (cpu.y >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.y == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;
  case 0xBC:
    v = cpuread(addrMode("ABSX"));
    cpu.y = v;

    if (cpu.y >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.y == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;

    // LDX
  case 0xA2:
    v = addrMode("IMM");
    cpu.x = v;

    if (cpu.x >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.x == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 2;
    break;
  case 0xAE:
    v = cpuread(addrMode("ABS"));
    cpu.x = v;

    if (cpu.x >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.x == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;
  case 0xBE:
    v = cpuread(addrMode("ABSY"));
    cpu.x = v;

    if (cpu.x >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.x == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;
  case 0xA6:
    v = cpuread(addrMode("ZPG"));
    cpu.x = v;

    if (cpu.x >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.x == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 3;
    break;
  case 0xB6:
    v = cpuread(addrMode("ZPGY"));
    cpu.x = v;

    if (cpu.x >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.x == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;

    // LDA
  case 0xA9:
    v = addrMode("IMM");
    cpu.a = v;

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 2;
    break;
  case 0xA5:
    v = cpuread(addrMode("ZPG"));
    cpu.a = v;

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 3;
    break;
  case 0xB5:
    v = cpuread(addrMode("ZPGX"));
    cpu.a = v;

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;
  case 0xa1:
    v = cpuread(addrMode("INDX"));
    cpu.a = v;

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 5;
    break;
  case 0xb1:
    v = cpuread(addrMode("INDY"));
    cpu.a = v;

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 5;
    break;
  case 0xAD:
    v = cpuread(addrMode("ABS"));
    cpu.a = v;

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;
  case 0xBD:
    v = cpuread(addrMode("ABSX"));
    cpu.a = v;

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;
  case 0xB9:
    v = cpuread(addrMode("ABSY"));
    cpu.a = v;

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;

    //DEC
  case 0xc6:
    v = addrMode("ZPG");
    cpuwrite((cpuread(v)-1) & 0xFF, v);

    if (cpuread(v) >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 5;
    break;
  case 0xd6:
    v = addrMode("ZPGX");
    cpuwrite((cpuread(v)-1) & 0xFF, v);

    if (cpuread(v) >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 6;
    break;
  case 0xce:
    v = addrMode("ABS");
    cpuwrite((cpuread(v)-1) & 0xFF, v);

    if (cpuread(v) >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    cpu.delay += 6;
    break;
  case 0xde:
    v = addrMode("ABSX");
    cpuwrite((cpuread(v)-1) & 0xFF, v);

    if (cpuread(v) >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    cpu.delay += 7;
    break;

    //INC
  case 0xe6:
    v = addrMode("ZPG");
    cpuwrite((cpuread(v)+1) & 0xFF, v);

    if (cpuread(v) >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    cpu.delay += 5;
    break;
  case 0xf6:
    v = addrMode("ZPGX");
    cpuwrite((cpuread(v)+1) & 0xFF, v);

    if (cpuread(v) >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    cpu.delay += 6;
    break;
  case 0xee:
    v = addrMode("ABS");
    cpuwrite((cpuread(v)+1) & 0xFF, v);

    if (cpuread(v) >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    cpu.delay += 6;
    break;
  case 0xfe:
    v = addrMode("ABSX");
    cpuwrite((cpuread(v)+1) & 0xFF, v);

    if (cpuread(v) >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    cpu.delay += 7;
    break;

    // INX
  case 0xE8:
    cpu.x = (cpu.x+1) & 0xFF;

    if (cpu.x >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.x == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    cpu.delay += 2;
    break;

    // INY
  case 0xc8:
    cpu.y = (cpu.y+1) & 0xFF;

    if (cpu.y >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.y == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    cpu.delay += 2;
    break;

    // DEX
  case 0xca:
    cpu.x = (cpu.x-1) & 0xFF;

    if (cpu.x >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.x == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    cpu.delay += 2;
    break;

    // DEY
  case 0x88:
    cpu.y = (cpu.y-1) & 0xFF;

    if (cpu.y >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.y == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    cpu.delay += 2;
    break;

    //TAX
  case 0xaa:
    cpu.x = cpu.a;

    if (cpu.x >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.x == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 2;
    break;

    //TXA
  case 0x8a:
    cpu.a = cpu.x;

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 2;
    break;

    //TAY
  case 0xa8:
    cpu.y = cpu.a;

    if (cpu.y >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.y == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 2;
    break;

    //TYA
  case 0x98:
    cpu.a = cpu.y;

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 2;
    break;

    //TSX
  case 0xba:
    cpu.x = cpu.s;

    if (cpu.x >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (cpu.x == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 2;
    break;

    // STY
  case 0x84:
    v = addrMode("ZPG");
    cpuwrite(cpu.y, v);

    cpu.delay += 3;
    break;
  case 0x8C:
    v = addrMode("ABS");
    cpuwrite(cpu.y, v);

    cpu.delay += 4;
    break;
  case 0x94:
    v = addrMode("ZPGX");
    cpuwrite(cpu.y, v);

    cpu.delay += 4;
    break;

    // STX
  case 0x86:
    v = addrMode("ZPG");
    cpuwrite(cpu.x, v);

    cpu.delay += 3;
    break;
  case 0x96:
    v = addrMode("ZPGY");
    cpuwrite(cpu.x, v);

    cpu.delay += 3;
    break;
  case 0x8E:
    v = addrMode("ABS");
    cpuwrite(cpu.x, v);

    cpu.delay += 4;
    break;

    // STA
  case 0x85:
    v = addrMode("ZPG");
    cpuwrite(cpu.a, v);

    cpu.delay += 3;
    break;
  case 0x95:
    v = addrMode("ZPGX");
    cpuwrite(cpu.a, v);

    cpu.delay += 4;
    break;
  case 0x8D:
    v = addrMode("ABS");
    cpuwrite(cpu.a, v);

    cpu.delay += 4;
    break;
  case 0x9D:
    v = addrMode("ABSX");
    cpuwrite(cpu.a, v);

    cpu.delay += 5;
    break;
  case 0x99:
    v = addrMode("ABSY");
    cpuwrite(cpu.a, v);

    cpu.delay += 5;
    break;
  case 0x81:
    v = addrMode("INDX");
    cpuwrite(cpu.a, v);

    cpu.delay += 6;
    break;
  case 0x91:
    v = addrMode("INDY");
    cpuwrite(cpu.a, v);

    cpu.delay += 6;
    break;

    // ASL
  case 0x06:
    v = addrMode("ZPG");

    // C
    if ((cpuread(v) >> 7) != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    cpuwrite((cpuread(v) << 1) & 0xFF, v);

    // N
    if ((cpuread(v) >> 7) != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    // Z
    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 5;
    break;
  case 0x16:
    v = addrMode("ZPGX");

    // C
    if ((cpuread(v) >> 7) != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    cpuwrite((cpuread(v) << 1) & 0xFF, v);

    // N
    if ((cpuread(v) >> 7) != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    // Z
    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 6;
    break;
  case 0x0E:
    v = addrMode("ABS");

    // C
    if ((cpuread(v) >> 7) != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    cpuwrite((cpuread(v) << 1) & 0xFF, v);

    // N
    if ((cpuread(v) >> 7) != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    // Z
    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 6;
    break;
  case 0x1E:
    v = addrMode("ABSX");

    // C
    if ((cpuread(v) >> 7) != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    cpuwrite((cpuread(v) << 1) & 0xFF, v);

    // N
    if ((cpuread(v) >> 7) != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    // Z
    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 7;
    break;
  case 0x0A:
    // C
    if ((cpu.a >> 7) != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    cpu.a = (cpu.a << 1) & 0xFF;

    // N
    if ((cpu.a >> 7) != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    // Z
    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 2;
    break;

    // LSR
  case 0x4a:
    // C
    if ((cpu.a & 0x1) != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    cpu.a = cpu.a >> 1;

    // N
    cpu.status &= 0b01111111;

    // Z
    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 2;
    break;
  case 0x46:
    v = addrMode("ZPG");
    // C
    if ((cpuread(v) & 0x1) != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    cpuwrite(cpuread(v)>>1, v);

    // N
    cpu.status &= 0b01111111;

    // Z
    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 5;
    break;
  case 0x56:
    v = addrMode("ZPGX");
    // C
    if ((cpuread(v) & 0x1) != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    cpuwrite(cpuread(v)>>1, v);

    // N
    cpu.status &= 0b01111111;

    // Z
    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 5;
    break;
  case 0x4E:
    v = addrMode("ABS");
    // C
    if ((cpuread(v) & 0x1) != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    cpuwrite(cpuread(v)>>1, v);

    // N
    cpu.status &= 0b01111111;

    // Z
    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 6;
    break;
  case 0x5E:
    v = addrMode("ABSX");
    // C
    if ((cpuread(v) & 0x1) != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    cpuwrite(cpuread(v)>>1, v);

    // N
    cpu.status &= 0b01111111;

    // Z
    if (cpuread(v) == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 6;
    break;

    // AND
  case 0x29:
    v = addrMode("IMM");

    cpu.a &= v;

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 2;
    break;
  case 0x25:
    v = cpuread(addrMode("ZPG"));

    cpu.a &= v;

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 3;
    break;
  case 0x35:
    v = cpuread(addrMode("ZPGX"));

    cpu.a &= v;

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0x2D:
    v = cpuread(addrMode("ABS"));

    cpu.a &= v;

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0x21:
    v = cpuread(addrMode("INDX"));

    cpu.a &= v;

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 6;
    break;
  case 0x31:
    v = cpuread(addrMode("INDY"));

    cpu.a &= v;

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 5;
    break;
  case 0x3D:
    v = cpuread(addrMode("ABSX"));

    cpu.a &= v;

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0x39:
    v = cpuread(addrMode("ABSY"));

    cpu.a &= v;

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;

    // ADC
  case 0x69:
    v = addrMode("IMM");

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 2;
    break;
  case 0x65:
    v = cpuread(addrMode("ZPG"));

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    cpu.delay += 3;
    break;
  case 0x75:
    v = cpuread(addrMode("ZPGX"));

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    cpu.delay += 4;
    break;
  case 0x6d:
    v = cpuread(addrMode("ABS"));

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    cpu.delay += 4;
    break;
  case 0x7d:
    v = cpuread(addrMode("ABSX"));

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    cpu.delay += 4;
    break;
  case 0x79:
    v = cpuread(addrMode("ABSY"));

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    cpu.delay += 4;
    break;
  case 0x61:
    v = cpuread(addrMode("INDX"));

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    cpu.delay += 6;
    break;
  case 0x71:
    v = cpuread(addrMode("INDY"));

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    cpu.delay += 5;
    break;

    // SBC
  case 0xE9:
    v = addrMode("IMM") ^ 0xFF;

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 2;
    break;
  case 0xE5:
    v = cpuread(addrMode("ZPG")) ^ 0xFF;

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 3;
    break;
  case 0xF5:
    v = cpuread(addrMode("ZPGX")) ^ 0xFF;

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0xED:
    v = cpuread(addrMode("ABS")) ^ 0xFF;

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0xFD:
    v = cpuread(addrMode("ABSX")) ^ 0xFF;

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0xF9:
    v = cpuread(addrMode("ABSY")) ^ 0xFF;

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0xE1:
    v = cpuread(addrMode("INDX")) ^ 0xFF;

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0xF1:
    v = cpuread(addrMode("INDY")) ^ 0xFF;

    old = cpu.a;

    oper = (cpu.a + v + (cpu.status & 0x1));

    cpu.a = oper & 0xFF;

    signed = (cpu.a ^ v) & (old ^ cpu.a) & 0x80;

    if (oper > 0xFF) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (signed != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;

  case 0x9A:
    cpu.s = cpu.x;
    break;

    // SEI
  case 0x78:
    cpu.status |= 0b00000100;

    cpu.delay += 2;
    break;

    // SED
  case 0xF8:
    cpu.status |= 0b00001000;

    cpu.delay += 2;
    break;

    // SEC
  case 0x38:
    cpu.status |= 0b00000001;

    cpu.delay += 2;
    break;

    // CLD
  case 0xD8:
    cpu.status &= 0b11110111;

    cpu.delay += 2;
    break;

    // CLC
  case 0x18:
    cpu.status &= 0b11111110;

    cpu.delay += 2;
    break;

    // CLI
  case 0x58:
    cpu.status &= 0b11111011;

    cpu.delay += 2;
    break;

    // CLV
  case 0xB8:
    cpu.status &= 0b10111111;

    cpu.delay += 2;
    break;

    // BPL
  case 0x10:
    v = addrMode("REL");

    if (cpu.status>>7 == 0) {
      cpu.pc = v;
      cpu.delay ++;
    }

    cpu.delay += 2;
    break;

    // BCS
  case 0xB0:
    v = addrMode("REL");

    if ((cpu.status & 0x1) == 1) {
      cpu.pc = v;
      cpu.delay ++;
    }

    cpu.delay += 2;
    break;

    // BCC
  case 0x90:
    v = addrMode("REL");

    if ((cpu.status & 0x1) == 0) {
      cpu.pc = v;
      cpu.delay ++;
    }

    cpu.delay += 2;
    break;

    // BEQ
  case 0xF0:
    v = addrMode("REL");

    if (((cpu.status >> 1) & 0x1) == 1) {
      cpu.pc = v;
      cpu.delay ++;
    }

    cpu.delay += 2;
    break;

    // BNE
  case 0xD0:
    v = addrMode("REL");

    if (((cpu.status >> 1) & 0x1) == 0) {
      cpu.pc = v;
      cpu.delay ++;
    }

    cpu.delay += 2;
    break;

    // BVS
  case 0x70:
    v = addrMode("REL");

    if (((cpu.status >> 6) & 0x1) == 1) {
      cpu.pc = v;
      cpu.delay ++;
    }

    cpu.delay += 2;
    break;

    // BVC
  case 0x50:
    v = addrMode("REL");

    if (((cpu.status >> 6) & 0x1) == 0) {
      cpu.pc = v;
      cpu.delay ++;
    }

    cpu.delay += 2;
    break;

    // BMI
  case 0x30:
    v = addrMode("REL");

    if (((cpu.status >> 7) & 0x1) == 1) {
      cpu.pc = v;
      cpu.delay ++;
    }

    cpu.delay += 2;
    break;

    // BIT
  case 0x24:
    v = cpuread(addrMode("ZPG"));

    oper = cpu.a & v;

    if ((v>>7) != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (((v >> 6) & 0x1) != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (oper == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 3;
    break;
  case 0x2C:
    v = cpuread(addrMode("ABS"));

    oper = cpu.a & v;

    if ((v>>7) != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    if (((v >> 6) & 0x1) != 0) {
      cpu.status |= 0b01000000;
    } else {
      cpu.status &= 0b10111111;
    }

    if (oper == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    cpu.delay += 4;
    break;

    //CMP
  case 0xC9:
    v = addrMode("IMM");
    oper = cpu.a - v;
    if (cpu.a == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.a >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 2;
    break;
  case 0xc5:
    v = cpuread(addrMode("ZPG"));
    oper = cpu.a - v;
    if (cpu.a == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.a >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 3;
    break;
  case 0xd5:
    v = cpuread(addrMode("ZPGX"));
    oper = cpu.a - v;
    if (cpu.a == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.a >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0xcd:
    v = cpuread(addrMode("ABS"));
    oper = cpu.a - v;
    if (cpu.a == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.a >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0xdd:
    v = cpuread(addrMode("ABSX"));
    oper = cpu.a - v;
    if (cpu.a == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.a >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0xd9:
    v = cpuread(addrMode("ABSY"));
    oper = cpu.a - v;
    if (cpu.a == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.a >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;
  case 0xc1:
    v = cpuread(addrMode("INDX"));
    oper = cpu.a - v;
    if (cpu.a == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.a >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 5;
    break;
  case 0xd1:
    v = cpuread(addrMode("INDY"));
    oper = cpu.a - v;
    if (cpu.a == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.a >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 5;
    break;

    //CPX
  case 0xE0:
    v = addrMode("IMM");
    oper = cpu.x - v;
    if (cpu.x == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.x >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 2;
    break;
  case 0xE4:
    v = cpuread(addrMode("ZPG"));
    oper = cpu.x - v;
    if (cpu.x == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.x >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 3;
    break;
  case 0xEc:
    v = cpuread(addrMode("ABS"));
    oper = cpu.x - v;
    if (cpu.x == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.x >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 3;
    break;

    //CPY
  case 0xC4:
    v = cpuread(addrMode("ZPG"));
    oper = cpu.y - v;
    if (cpu.y == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.y >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 3;
    break;
  case 0xCC:
    v = cpuread(addrMode("ABS"));
    oper = cpu.y - v;
    if (cpu.y == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.y >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 3;
    break;
  case 0xC0:
    v = addrMode("IMM");
    oper = cpu.y - v;
    if (cpu.y == v) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (cpu.y >= v) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (((oper >> 7) & 0x1) == 1) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 2;
    break;

    //PLP
  case 0x28:
    v = stackread();
    cpu.status = v;
    cpu.status |= 0b00100000;
    cpu.status &= 0b11101111;

    cpu.delay += 4;
    break;

    //PHP
  case 0x08:
    v = cpu.status;
    v |= 0b00010000;
    stackwrite(v);

    cpu.delay += 3;
    break;

    //PHA
  case 0x48:
    stackwrite(cpu.a);

    cpu.delay += 3;
    break;

    // PLA
  case 0x68:
    cpu.a = stackread();

    if (cpu.a == 0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (cpu.a >> 7 != 0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }

    cpu.delay += 4;
    break;

    //ROL
  case 0x26:
    v = addrMode("ZPG");
    b0 = cpuread(v)>>7;
    cpuwrite(((cpuread(v)<<1)+(cpu.status&0x1))&0xFF, v);
    if (b0 == 1) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (cpuread(v)==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (((cpuread(v)>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 5;
    break;
  case 0x36:
    v = addrMode("ZPGX");
    b0 = cpuread(v)>>7;
    cpuwrite(((cpuread(v)<<1)+(cpu.status&0x1))&0xFF, v);
    if (b0 == 1) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (cpuread(v)==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (((cpuread(v)>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 6;
    break;
  case 0x2e:
    v = addrMode("ABS");
    b0 = cpuread(v)>>7;
    cpuwrite(((cpuread(v)<<1)+(cpu.status&0x1))&0xFF, v);
    if (b0 == 1) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (cpuread(v)==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (((cpuread(v)>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 6;
    break;
  case 0x3e:
    v = addrMode("ABSX");
    b0 = cpuread(v)>>7;
    cpuwrite(((cpuread(v)<<1)+(cpu.status&0x1))&0xFF, v);
    if (b0 == 1) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (cpuread(v)==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (((cpuread(v)>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 6;
    break;
  case 0x2A:
    b0 = cpu.a>>7;
    cpu.a = ((cpu.a<<1)+(cpu.status&0x1))&0xFF;
    if (b0 == 1) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 2;
    break;

    //ROR
  case 0x66:
    v = addrMode("ZPG");
    b0 = cpuread(v)&0x1;
    cpuwrite(((cpuread(v)>>1)+((cpu.status&0x1)<<7))&0xFF, v);
    if (b0 != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (cpuread(v)==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (((cpuread(v)>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 5;
    break;
  case 0x76:
    v = addrMode("ZPGX");
    b0 = cpuread(v)&0x1;
    cpuwrite(((cpuread(v)>>1)+((cpu.status&0x1)<<7))&0xFF, v);
    if (b0 != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (cpuread(v)==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (((cpuread(v)>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 5;
    break;
  case 0x6e:
    v = addrMode("ABS");
    b0 = cpuread(v)&0x1;
    cpuwrite(((cpuread(v)>>1)+((cpu.status&0x1)<<7))&0xFF, v);
    if (b0 != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (cpuread(v)==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (((cpuread(v)>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 7;
    break;
  case 0x7e:
    v = addrMode("ABSX");
    b0 = cpuread(v)&0x1;
    cpuwrite(((cpuread(v)>>1)+((cpu.status&0x1)<<7))&0xFF, v);
    if (b0 != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (cpuread(v)==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (((cpuread(v)>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 7;
    break;
  case 0x6A:
    b0 = cpu.a&0x1;
    cpu.a = ((cpu.a>>1)+((cpu.status&0x1)<<7))&0xFF;
    if (b0 != 0) {
      cpu.status |= 0b00000001;
    } else {
      cpu.status &= 0b11111110;
    }
    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }
    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 2;
    break;

    // ORA
  case 0x05:
    v = cpuread(addrMode("ZPG"));

    cpu.a |= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 3;
    break;
  case 0x15:
    v = cpuread(addrMode("ZPGX"));

    cpu.a |= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 4;
    break;
  case 0x0d:
    v = cpuread(addrMode("ABS"));

    cpu.a |= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 4;
    break;
  case 0x1d:
    v = cpuread(addrMode("ABSX"));

    cpu.a |= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 4;
    break;
  case 0x19:
    v = cpuread(addrMode("ABSY"));

    cpu.a |= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 4;
    break;
  case 0x01:
    v = cpuread(addrMode("INDX"));

    cpu.a |= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 6;
    break;
  case 0x11:
    v = cpuread(addrMode("INDY"));

    cpu.a |= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 5;
    break;
  case 0x09:
    v = addrMode("IMM");

    cpu.a |= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 2;
    break;

    // EOR
  case 0x49:
    v = addrMode("IMM");

    cpu.a ^= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 2;
    break;
  case 0x45:
    v = cpuread(addrMode("ZPG"));

    cpu.a ^= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 3;
    break;
  case 0x55:
    v = cpuread(addrMode("ZPGX"));

    cpu.a ^= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 3;
    break;
  case 0x4d:
    v = cpuread(addrMode("ABS"));

    cpu.a ^= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 4;
    break;
  case 0x5d:
    v = cpuread(addrMode("ABSX"));

    cpu.a ^= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 4;
    break;
  case 0x59:
    v = cpuread(addrMode("ABSY"));

    cpu.a ^= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 4;
    break;
  case 0x41:
    v = cpuread(addrMode("INDX"));

    cpu.a ^= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 3;
    break;
  case 0x51:
    v = cpuread(addrMode("INDY"));

    cpu.a ^= v;

    if (cpu.a==0) {
      cpu.status |= 0b00000010;
    } else {
      cpu.status &= 0b11111101;
    }

    if (((cpu.a>>7)&0x1)!=0) {
      cpu.status |= 0b10000000;
    } else {
      cpu.status &= 0b01111111;
    }
    cpu.delay += 3;
    break;

  default:
    //println("UNKNOWN INSTRUCTION - "+hex(op,2));
    cpu.pc -= 1;
    break;
  }
}

int addrMode(String type) {
  int value;
  int old;
  switch(type) {
  case "IMM":
    value = cpuread(cpu.pc);
    cpu.pc=(cpu.pc+1)&0xFFFF;
    return value&0xFF;

  case "ABS":
    value = (cpuread(cpu.pc+1)<<8)+cpuread(cpu.pc);
    cpu.pc=(cpu.pc+2)&0xFFFF;
    return value&0xFFFF;

  case "ABSX":
    value = (cpuread(cpu.pc+1)<<8)+cpuread(cpu.pc);
    if ((value&0xFF) + cpu.x > 0xFF)cpu.delay++;
    cpu.pc=(cpu.pc+2)&0xFFFF;
    return (value + cpu.x)&0xFFFF;

  case "ABSY":
    value = (cpuread(cpu.pc+1)<<8)+cpuread(cpu.pc);
    if ((value&0xFF) + cpu.y > 0xFF)cpu.delay++;
    cpu.pc=(cpu.pc+2)&0xFFFF;
    return (value + cpu.y)&0xFFFF;

  case "ZPG":
    value = cpuread(cpu.pc);
    cpu.pc=(cpu.pc+1)&0xFFFF;
    return value&0xFF;

  case "ZPGX":
    value = cpuread(cpu.pc);
    cpu.pc=(cpu.pc+1)&0xFFFF;
    return (value+cpu.x)&0xFF;

  case "ZPGY":
    value = cpuread(cpu.pc);
    cpu.pc=(cpu.pc+1)&0xFFFF;
    return (value+cpu.y)&0xFF;

  case "REL":
    value = cpuread(cpu.pc)<<24>>24;

    if ((cpu.pc & 0xFF) + value < 0 || (cpu.pc & 0xFF) + value > 0xFF) cpu.delay += 2;

    cpu.pc=(cpu.pc+1)&0xFFFF;
    return (cpu.pc + value)&0xFFFF;

  case "IND":
    value = cpuread((cpu.pc+1)&0xFFFF)<<8;

    value += cpuread(cpu.pc);

    old = value;

    if ((old&0xFF)+1==256) {
      value = (cpuread(value&0xFF00)<<8);
    } else {
      value = (cpuread((value+1)&0xFFFF)<<8);
    }

    value += cpuread(old);

    cpu.pc=(cpu.pc+2)&0xFFFF;
    return value&0xFFFF;

  case "INDX":
    value = cpuread(cpu.pc)+cpu.x;
    value = (cpuread((value+1)&0xFF)<<8)+cpuread(value&0xFF);
    cpu.pc=(cpu.pc+1)&0xFFFF;
    return value&0xFFFF;

  case "INDY":
    value = cpuread(cpu.pc);
    value = (cpuread((value+1)&0xFF)<<8)+cpuread(value);
    if ((value&0xFF) + cpu.y > 0xFF)cpu.delay++;
    cpu.pc=(cpu.pc+1)&0xFFFF;
    return (value+cpu.y)&0xFFFF;

  default:
    println("UNKNOWN ADDRESSING MODE. - "+type);
    return 0;
  }
}

void cpuwrite(int v, int addr) {
  addr &= 0xFFFF;

  if (addr>=0x8000) {
    cpu.banksel = v;

    for (int i = 0; i<cpu.banks[cpu.banksel].length; i++) {
      cpu.bus[0x8000+i] = (int)cpu.banks[cpu.banksel][i];
    }
    return;
  }

  switch(addr) {
  case 0x2002:
    break;

    // OAMADDR
  case 0x2003:
    cpu.bus[addr] = v;

    ppu.oamaddr = v;
    cpu.bus[0x2004] = ppu.oam[ppu.oamaddr];
    break;

    // OAMDATA
  case 0x2004:
    cpu.bus[addr] = v;

    ppu.oam[ppu.oamaddr] = v;

    ppu.oamaddr = (ppu.oamaddr+1)%ppu.oam.length;
    cpu.bus[0x2004] = ppu.oam[ppu.oamaddr];
    break;


    // OAMDMA
  case 0x4014:
    cpu.bus[addr] = v;

    for (int i = 0; i<256; i++) {
      ppu.oam[i] = cpu.bus[(v<<8)+i];
    }
    break;

    // PPUSCROLL
  case 0x2005:
    cpu.bus[addr] = v;

    if (ppu.wl) {
      ppu.scY = v;
    } else {
      ppu.scX = v;
    }

    ppu.wl = !ppu.wl;
    break;

    //PPUADDR
  case 0x2006:
    cpu.bus[addr] = v;

    if (!ppu.wl) {
      ppu.addr &= 0x00FF;
      ppu.addr |= (v)<<8;
    } else {
      ppu.addr &= 0xFF00;
      ppu.addr |= v;
    }
    ppu.wl = !ppu.wl;
    break;

    //PPUDATA
  case 0x2007:
    cpu.bus[addr] = v;

    ppu.bus[ppu.addr%ppu.bus.length] = cpu.bus[addr];
    if (ppu.addr>=0x2000) {
      if (ppu.horiz) {
        if (ppu.addr < 0x2800)ppu.bus[ppu.addr+0x800] = cpu.bus[addr];
        if (ppu.addr >= 0x2800)ppu.bus[ppu.addr-0x800] = cpu.bus[addr];
      } else {
        if (ppu.addr < 0x2400)ppu.bus[ppu.addr+0x400] = cpu.bus[addr];
        if (ppu.addr >= 0x2400&&ppu.addr < 0x2800)ppu.bus[ppu.addr-0x400] = cpu.bus[addr];
        if (ppu.addr >= 0x2800&&ppu.addr < 0x2C00)ppu.bus[ppu.addr+0x400] = cpu.bus[addr];
        if (ppu.addr >= 0x2C00&&ppu.addr < 0x3000)ppu.bus[ppu.addr-0x400] = cpu.bus[addr];
      }
    }

    if (ppu.addr>=0x3f00) {
      int tempaddr = (ppu.addr-0x3f00)%0x20;

      for (int i = 0; i<0x4000; i+=0x20) {
        ppu.bus[tempaddr+i+0x3f00] = cpu.bus[addr];
      }
      
      tempaddr = (ppu.addr-0x3f00)%0x10;
      
      if(tempaddr==0){
        for (int i = 0; i<0x4000; i+=0x10) {
          ppu.bus[tempaddr+i+0x3f00] = cpu.bus[addr];
        }
      }
    }

    if ((cpu.bus[0x2000]&0x4)==4) {
      ppu.addr=(ppu.addr+32)&0x3fff;
    } else {
      ppu.addr=(ppu.addr+1)&0x3fff;
    }
    break;

    // CTRLPOLL
  case 0x4016:
    cpu.bus[addr] = v;

    cpu.ctrl1poll = v&0x1;

    if (cpu.ctrl1poll==0) {
      for (int o = 0; o<8; o++) {
        boolean buttonpress = (boolean)nesctrl[o][1];
        if (buttonpress) {
          cpu.ctrl1 |= 1<<o;
        } else {
          cpu.ctrl1 &= 0b11111111^(1<<o);
        }
      }
    }
    break;

    // APU
  case 0x4002:
    cpu.bus[addr] = v;

    apu.timer1 = (((cpu.bus[0x4003]&0b111)<<8)+cpu.bus[0x4002]);
    break;

  case 0x4003:
    cpu.bus[addr] = v;

    apu.lc1 = apulength[cpu.bus[addr]>>3];

    apu.timer1 = (((cpu.bus[0x4003]&0b111)<<8)+cpu.bus[0x4002]);
    break;

  case 0x4006:
    cpu.bus[addr] = v;

    apu.timer2 = (((cpu.bus[0x4007]&0b111)<<8)+cpu.bus[0x4006]);
    break;

  case 0x4007:
    cpu.bus[addr] = v;

    apu.lc2 = apulength[cpu.bus[addr]>>3];

    apu.timer2 = (((cpu.bus[0x4007]&0b111)<<8)+cpu.bus[0x4006]);
    break;

  case 0x400A:
    cpu.bus[addr] = v;

    apu.timer3 = (((cpu.bus[0x400B]&0b111)<<8)+cpu.bus[0x400A]);
    break;

  case 0x400B:
    cpu.bus[addr] = v;

    apu.lc3 = apulength[cpu.bus[addr]>>3]-1;

    apu.timer3 = (((cpu.bus[0x400B]&0b111)<<8)+cpu.bus[0x400A]);
    break;
    
  case 0x400F:
    cpu.bus[addr] = v;

    apu.lc4 = apulength[cpu.bus[addr]>>3]-1;
    break;

  default:
    cpu.bus[addr] = v;
    break;
  }
}

int cpuread(int addr) {
  addr &= 0xFFFF;

  switch(addr) {
  case 0x4016:
    if (cpu.ctrl1poll==0) {
      cpu.bus[0x4016] = cpu.ctrl1&0x1;

      cpu.ctrl1 = cpu.ctrl1>>1;
    }
    break;
  }

  int value = cpu.bus[addr];

  switch(addr) {
  case 0x2002:
    cpu.bus[0x2002] &= 0b01111111;
    ppu.wl = false;
    break;

  case 0x2007:
    value = ppu.datab;
  
    ppu.datab = ppu.bus[ppu.addr%ppu.bus.length];
    
    if (ppu.addr>=0x3f00)value = ppu.datab;

    if ((cpu.bus[0x2000]&0x4)==4) {
      ppu.addr=(ppu.addr+32)&0x3fff;
    } else {
      ppu.addr=(ppu.addr+1)&0x3fff;
    }
    break;
  }

  return value;
}

void stackwrite(int v) {
  cpu.bus[0x100 + cpu.s] = v;
  cpu.s = (cpu.s - 1) & 0xFF;
}

int stackread() {
  cpu.s = (cpu.s + 1) & 0xFF;
  return cpu.bus[0x100 + cpu.s];
}

void drawSprites(int o, int fg) {
  int addr = ppu.oam[o+1];
  int pal = (ppu.oam[o+2]&0b11)+4;

  int flipx = (ppu.oam[o+2]>>6)&0x1;
  int flipy = (ppu.oam[o+2]>>7)&0x1;

  if (flipx==1) {
    flipx = (((ppu.slX-ppu.oam[o+3]) % 8));
  } else {
    flipx = (7-((ppu.slX-ppu.oam[o+3]) % 8));
  }

  if (flipy==1) {
    if (((cpu.bus[0x2000]>>5)&0x1)==1) {
      flipy = (addr>>1<<1)*16 + 7 - ((ppu.slY-ppu.oam[o]-1) % 8) - floor((8-(ppu.slY-ppu.oam[o]-1))/8)*16;
    } else {
      flipy = addr*16 + 7 - ((ppu.slY-ppu.oam[o]-1) % 8);
    }
  } else {
    if (((cpu.bus[0x2000]>>5)&0x1)==1) {
      flipy = (addr>>1<<1)*16 + ((ppu.slY-ppu.oam[o]-1) % 8) + floor((ppu.slY-ppu.oam[o]-1)/8)*16;
    } else {
      flipy = addr*16 + ((ppu.slY-ppu.oam[o]-1) % 8);
    }
  }

  int tile;
  if (((cpu.bus[0x2000]>>5)&0x1)==1) {
    tile = ((ppu.bus[flipy + (0x1000 * (addr&0x1))] >> (flipx)) & 0x1) + ((ppu.bus[flipy + (0x1000 * (addr&0x1)) + 8] >> (flipx)) & 0x1) * 2;
  } else {
    if (((cpu.bus[0x2000]>>3)&0x1)==0) {
      tile = ((ppu.bus[flipy] >> (flipx)) & 0x1) + ((ppu.bus[flipy + 8] >> (flipx)) & 0x1) * 2;
    } else {
      tile = ((ppu.bus[flipy + (0x1000 * ((cpu.bus[0x2000]>>3)&0x1))] >> (flipx)) & 0x1) + ((ppu.bus[flipy + (0x1000 * ((cpu.bus[0x2000]>>3)&0x1)) + 8] >> (flipx)) & 0x1) * 2;
    }
  }

  int pixel = ppu.bus[0x3f00 + pal*4 + tile];

  int ppos = (ppu.slX+ppu.slY*256)%ppu.display.pixels.length;

  if (ppu.sprcount<=8) {
    if ((cpu.bus[0x2001]&0b10000)>0) {
      if (tile>0) {
        if (fg==0) {
          ppu.display.pixels[ppos] = ppu.palette[pixel];
        } else {
          if (ppu.display.pixels[ppos]==ppu.palette[ppu.bus[0x3f00]])ppu.display.pixels[(ppu.slX+ppu.slY*256)%ppu.display.pixels.length] = ppu.palette[pixel];
        }
        if (o==0&&ppu.display.pixels[ppos]!=ppu.palette[ppu.bus[0x3f00]]) {
          if (((cpu.bus[0x2002]>>6)&0x1)==0) {
            //println("SPRITE 0 HIT AT: ("+ppu.slX+", "+ppu.slY+")");
            cpu.bus[0x2002] |= 0b01000000;
          }
        }
      }
    }
  } else {
    ppu.bus[0x2002] |= 0b00100000;
  }
}

void loadROM(File selection) {
  if (selection == null) {
    println("Window was closed or the user hit cancel, reopen prompt.");
    selectInput("Select a .NES file to load.", "loadROM");
  }else{
    cpu.bus = new int[0x10000];
    ppu.bus = new int[0x10000];
    
    byte[] b = loadBytes(selection);

    int prgsize = 16384 * b[4];
    int chrsize = 8192 * b[5];
  
    println("PRGSIZE - "+prgsize);
    if(chrsize==0){
      println("CHRRAM USED");
    }else{
      println("CHRSIZE - "+chrsize);
    }
    
    if((b[6]&0x1)==1){
      println("Horizontal Nametable Arrangement");
    }else{
      println("Vertical Nametable Arrangement");
    }
  
    println();
  
    switch(b[6]>>4) {
    case 0:
      println("NROM Mapper");
  
      if ((b[6]&0x1)==1) {
        ppu.horiz = true;
      } else {
        ppu.horiz = false;
      }
  
      if (prgsize == 16384) {
        for (int i = 0; i<prgsize; i++) {
          cpu.bus[i+0xC000] = b[i+0x10]&0xFF;
        }
      } else {
        for (int i = 0; i<prgsize; i++) {
          cpu.bus[i+0x8000] = b[i+0x10]&0xFF;
        }
      }
  
      for (int i = 0; i<chrsize; i++) {
        ppu.bus[i] = b[i+0x10+prgsize]&0xFF;
      }
  
      //cpu.pc = 0xC000;
      cpu.pc = (cpu.bus[0xFFFD]<<8)+cpu.bus[0xFFFC];
  
      println("RESET - "+hex((cpu.bus[0xFFFD]<<8)+cpu.bus[0xFFFC], 4));
      break;
  
    case 2:
      println("UNROM Mapper");
  
      if ((b[6]&0x1)==1) {
        ppu.horiz = true;
      } else {
        ppu.horiz = false;
      }
  
      // prepare banks
      cpu.banks = (int[][])expand(cpu.banks, prgsize/16384);
  
      for (int i = 0; i<prgsize/16384; i++) {
        int[] temp = {};
  
        for (int o = 0; o<16384; o++) {
          temp = append(temp, b[o+0x10+i*16384]&0xFF);
        }
  
        cpu.banks[i] = temp;
      }
  
      // default to bank 0
      for (int i = 0; i<16384; i++) {
        cpu.bus[i+0x8000] = (int)cpu.banks[0][i];
      }
  
      // locked last bank for $C000 to $FFFF
      for (int i = 0; i<16384; i++) {
        cpu.bus[i+0xC000] = (int)cpu.banks[cpu.banks.length-1][i];
      }
  
      for (int i = 0; i<chrsize; i++) {
        ppu.bus[i] = b[i+0x10+prgsize]&0xFF;
      }
  
      //cpu.pc = 0x8001;
      cpu.pc = (cpu.bus[0xFFFD]<<8)+cpu.bus[0xFFFC];
  
      println("RESET - "+hex((cpu.bus[0xFFFD]<<8)+cpu.bus[0xFFFC], 4));
      break;
  
    default:
      println("Unknown Mapper - " + ((b[6]&0xFF)>>4));
      break;
    }
    
    apu.lc1 = 0;
    apu.lc2 = 0;
    apu.lc3 = 0;
    apu.lc4 = 0;
  
    for (int i = 0; i<256; i++) {
      ppu.oam[i] = 0xFF;
    }
  }
}
