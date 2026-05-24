newRicoh2A03 cpu;

class newRicoh2A03 { // Implementation of the 2A03, hopefully sub-cycle accurate.
  // general constants
  float SPEED = 29780.5; // this is cycles that occur every frame (NTSC: 29780.5 cycles per frame at 60hz)
  float cpuCycles = 0; // counting for granularity of clock rate
  
  int MAGIC = 0xEE; // used for ANE instructions, it's magic (waow)
  
  // internal registers
  int a = 0; // accumulator
  int x = 0; // x
  int y = 0; // y

  int p = 0b00100100; // status register

  int pc = 0; // program counter / pointer

  int s = 252; // stack pointer

  // variables for parity with the Ricoh 2A03 Instructions PDF by L. Spiro
  int[] vectors = {0xFFFC, 0xFFFA, 0xFFFE};
  int opCode = 0;
  int operand = 0;
  int address = 0;
  int pointer = 0;
  int target = 0;
  int vector = 0;
  int lowBit = 0;
  int hiBit = 0;
  int mask = 0;
  int result16 = 0;
  int val = 0;
  int high = 0;
  int anx = 0;
  boolean jump = false;
  boolean boundaryCrossed = false;
  
  // sub-cycle counter
  int subCycle = 0;
  int clocks = 0; // runs independently of subCycle
  
  // variables to keep track of unimplemented instructions, etc.
  boolean jammed = false;
  boolean unimplemented = false;
  boolean runningNMI = false;
  boolean waitingNMI = false;
  
  // oam dma shananigans
  int oamDMA = 0;
  int oamHi = 0;
  
  // TODO: all applicable delays with setting A and flags
  
  void clock() {
    clocks = (clocks + 1) % 4;
    
    if (oamDMA > 0) {
      if (clocks == 0) {
        int oamByte = cpuBus.read(oamHi + ppu.oamAddr);
        cpuBus.write(0x2004, oamByte);
        oamDMA -= 1;
      }
      return;
    }
    
    if ((subCycle & 1) == 1) {
      pollInterrupts();
    }
    
    if (!runningNMI) {
      switch (opCode) {
        // nops
        // implied
        case 0x1A:
        case 0x3A:
        case 0x5A:
        case 0x7A:
        case 0xDA:
        case 0xEA:
        case 0xFA:
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: break;
            
            case 3: fetch();
              break;
          }
          break;
        
        // immediate
        case 0x80:
        case 0x82:
        case 0x89:
        case 0xC2:
        case 0xE2:
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
              break;
            case 3: fetch();
              break;
          }
          break;
          
        // zero-page
        case 0x04:
        case 0x44:
        case 0x64:
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: fetch();
              break;
          }
          break;
          
        // zero-page, x-indexed
        case 0x14:
        case 0x34:
        case 0x54:
        case 0x74:
        case 0xD4:
        case 0xF4:
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: fetch();
              break;
          }
          break;
          
        // absolute
        case 0x0C:
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: fetch();
              break;
          }
          break;
          
        // absolute, x-indexed
        case 0x1C:
        case 0x3C:
        case 0x5C:
        case 0x7C:
        case 0xDC:
        case 0xFC:
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXR(-1);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
        
        // jams
        case 0x02:
        case 0x12:
        case 0x22:
        case 0x32:
        case 0x42:
        case 0x52:
        case 0x62:
        case 0x72:
        case 0x92:
        case 0xB2:
        case 0xD2:
        case 0xF2:
          jam();
          break;
        
        case 0x00: // BRK
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: incPC();
              break;
            case 3: cpuBus.write(s | 0x100, u8(pc >> 8));
              break;
            case 4: break;
            
            case 5: cpuBus.write(u8(s - 1) | 0x100, u8(pc));
              break;
            case 6: vector = vectors[2];
              break;
            case 7: cpuBus.write(u8(s - 2) | 0x100, p | 0b00110000);
              break;
            case 8: s = u8(s - 3);
              break;
            case 9: writeAddressL(cpuBus.read(vector));
              break;
            case 10: p |= 0b00000100;
              break;
            case 11: writeAddressH(cpuBus.read(vector + 1));
              break;
            case 12: pc = address;
              break;
            case 13: fetch();
              break;
          }
          break;
          
        case 0x01: // ORA, ind, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: a |= operand;
                     p = (p & 0b01111101)
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x03: // SLO, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(address, operand);
              break;
            case 12: p = (p & 0b11111110) | (operand >> 7);
                     operand = u8(operand << 1);
                     a |= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 13: cpuBus.write(address, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0x05: // ORA, zpg
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: a |= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 5: fetch();
              break;
          }
          break;
         
        case 0x06: // ASL, zpg
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: cpuBus.write(address, operand);
              break;
            case 6: p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1);
                    p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
          }
          break;
          
        case 0x07: // SLO, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: cpuBus.write(address, operand);
              break;
            case 6: p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1);
                    a |= operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x08: // PHP
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: operand = (p | 0x30);
              break;
            case 3: cpuBus.write(s | 0x100, operand);
              break;
            case 4: s = u8(s - 1);
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0x09: // ORA, imm
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: pc = u16(pc + 1);
                    a |= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x0A: // ASL, impl
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: p = (p & 0b11111110) | (a >> 7);
                    a = u8(a << 1);
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x0B: // ANC, imm
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: pc = u16(pc + 1);
                    a &= operand;
                    p = (p & 0b01111100)
                    | (a >> 7) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x0D: // ORA, abs
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: a |= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x0E: // ASL, abs
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1);
                    p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
          }
          break;
          
        case 0x0F: // SLO, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1);
                    a |= operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x10: // BPL, rel
          switch(subCycle) {
            case 0: incPC();
                    jump = ((p & 0x80) == 0);
              break;
            case 1: operand = cpuBus.read(pc);
                    if (jump) {
                      address = u16(i8(operand) + pc + 1);
                      boundaryCrossed = (address & 0xFF00) != (u16(pc + 1) & 0xFF00);
                      if (!boundaryCrossed) pollInterrupts();
                    } else {
                      pollInterrupts();
                    }
             break;
           case 2: incPC();
                   if (!jump) subCycle += 4;
             break;
           case 3: cpuBus.read(pc);
             break;
           case 4: writePCL(u8(address));
                   if (!boundaryCrossed) subCycle += 2;
             break;
           case 5: cpuBus.read(pc);
                   pollInterrupts();
             break;
           case 6: writePCH(address >> 8);
             break;
           case 7: fetch();
             break;
          }
          break;
          
        case 0x11: // ORA, ind, y
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYR(-1);
              break;
            case 10: a |= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x13: // SLO, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYRMW(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(pointer, operand);
              break;
            case 12: p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1);
                    a |= operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 13: cpuBus.write(pointer, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0x15: // ORA, zpg, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: a |= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x16: // ASL, zpg, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1);
                    p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
          }
          break;
          
        case 0x17: // SLO, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1);
                    a |= operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x18: // CLC
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: p &= ~1;
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x19: // ORA, abs, y
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYR(-1);
              break;
            case 8: a |= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0x1B: // SLO, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: p = (p & 0b11111110) | (operand >> 7);
                     operand = u8(operand << 1);
                     a |= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x1D: // ORA, abs, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXR(-1);
              break;
            case 8: a |= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0x1E: // ASL, abs, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: p = (p & 0b11111110) | (operand >> 7);
                     operand = u8(operand << 1);
                     p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
          }
          break;
          
        case 0x1F: // SLO, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: p = (p & 0b11111110) | (operand >> 7);
                     operand = u8(operand << 1);
                     a |= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x20: // JSR, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: address = cpuBus.read(pc);
              break;
            case 2: incPC();
              break;
            case 3: operand = cpuBus.read(s | 0x100);
              break;
            case 4: break;
            
            case 5: cpuBus.write(s | 0x100, pc >> 8);
              break;
            case 6: break;
            
            case 7: cpuBus.write(u8(s - 1) | 0x100, u8(pc));
              break;
            case 8: break;
              
            case 9: writeAddressH(cpuBus.read(pc));
              break;
            case 10: s = u8(s - 2);
                     pc = address;
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x21: // AND, ind, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: a &= operand;
                     p = (p & 0b01111101)
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x23: // RLA, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(address, operand);
              break;
            case 12: lowBit = p & 1;
                     p = (p & 0b11111110) | (operand >> 7);
                     operand = u8(operand << 1) | (lowBit);
                     a &= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 13: cpuBus.write(address, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0x24: // BIT, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: p = (p & 0b00111101) | (operand & 0x40) | (operand & 0x80) | ((operand & a) == 0 ? 2 : 0);
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0x25: // AND, zpg
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: a &= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0x26: // ROL, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: cpuBus.write(address, operand);
              break;
            case 6: lowBit = p & 1;
                    p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1) | (lowBit);
                    p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x27: // RLA, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: cpuBus.write(address, operand);
              break;
            case 6: lowBit = p & 1;
                    p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1) | (lowBit);
                    a &= operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x28: // PLP
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: break;
            
            case 3: operand = cpuBus.read(s | 0x100);
              break;
            case 4: s = u8(s + 1);
              break;
            case 5: operand = cpuBus.read(s | 0x100);
              break;
            case 6: p = ((operand & 0b11101111) | 0b00100000);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x29: // AND, imm
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    a &= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x2A: // ROL, a
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc); 
              break;
            case 2: lowBit = p & 1;
                    p = (p & 0b11111110) | (a >> 7);
                    a = u8(a << 1) | (lowBit);
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x2B: // ANC, imm
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    a &= operand;
                    p = (p & 0b01111100)
                    | (a >> 7) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x2C: // BIT, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: p = (p & 0b00111101) | (operand & 0x40) | (operand & 0x80) | ((operand & a) == 0 ? 2 : 0);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x2D: // AND, abs
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: a &= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x2E: // ROL, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: lowBit = p & 1;
                    p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1) | (lowBit);
                    p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x2F: // RLA, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: lowBit = p & 1;
                    p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1) | (lowBit);
                    a &= operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x30: // BMI, rel
          switch(subCycle) {
            case 0: incPC();
                    jump = ((p & 0x80) == 0x80);
              break;
            case 1: operand = cpuBus.read(pc);
                    if (jump) {
                      address = u16(i8(operand) + pc + 1);
                      boundaryCrossed = (address & 0xFF00) != (u16(pc + 1) & 0xFF00);
                      if (!boundaryCrossed) pollInterrupts();
                    } else {
                      pollInterrupts();
                    }
             break;
           case 2: incPC();
                   if (!jump) subCycle += 4;
             break;
           case 3: cpuBus.read(pc);
             break;
           case 4: writePCL(u8(address));
                   if (!boundaryCrossed) subCycle += 2;
             break;
           case 5: cpuBus.read(pc);
                   pollInterrupts();
             break;
           case 6: writePCH(address >> 8);
             break;
           case 7: fetch();
             break;
          }
          break;
          
        case 0x31: // AND, ind, y
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYR(-1);
              break;
            case 10: a &= operand;
                     p = (p & 0b01111101)
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x33: // RLA, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYRMW(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(pointer, operand);
              break;
            case 12: lowBit = p & 1;
                     p = (p & 0b11111110) | (operand >> 7);
                     operand = u8(operand << 1) | (lowBit);
                     a &= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 13: cpuBus.write(pointer, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0x35: // AND, zpg, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: a &= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x36: // ROL, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: lowBit = p & 1;
                    p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1) | (lowBit);
                    p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x37: // RLA, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: lowBit = p & 1;
                    p = (p & 0b11111110) | (operand >> 7);
                    operand = u8(operand << 1) | (lowBit);
                    a &= operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x38: // SEC
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: p |= 1;
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x39: // AND, abs, y
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYR(-1);
              break;
            case 8: a &= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0x3B: // RLA, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: lowBit = p & 1;
                     p = (p & 0b11111110) | (operand >> 7);
                     operand = u8(operand << 1) | (lowBit);
                     a &= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x3D: // AND, abs, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXR(-1);
              break;
            case 8: a &= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0x3E: // ROL, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: lowBit = p & 1;
                     p = (p & 0b11111110) | (operand >> 7);
                     operand = u8(operand << 1) | (lowBit);
                     p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x3F: // RLA, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: lowBit = p & 1;
                     p = (p & 0b11111110) | (operand >> 7);
                     operand = u8(operand << 1) | (lowBit);
                     a &= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x40: // RTI
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: operand = cpuBus.read(pc);
              break;
            case 2: incPC();
              break;
            case 3: operand = cpuBus.read(s | 0x100);
              break;
            case 4: break;
            
            case 5: operand = cpuBus.read(u8(s + 1) | 0x100);
              break;
            case 6: mask = 0b00110000;
                    p = (operand & ~mask) | (p & mask);
              break;
            case 7: writeTargetL(cpuBus.read(u8(s + 2) | 0x100));
              break;
            case 8: s = u8(s + 3);
              break;
            case 9: writeTargetH(cpuBus.read(s | 0x100));
              break;
            case 10: pc = target;
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x41: // EOR, ind, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: a ^= operand;
                     p = (p & 0b01111101)
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x43: // SRE, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(address, operand);
              break;
            case 12: p = (p & 0b11111110) | (operand & 1);
                     operand >>= 1;
                     a ^= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 13: cpuBus.write(address, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0x45: // EOR, zpg
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: a ^= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0x46: // LSR, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: cpuBus.write(address, operand);
              break;
            case 6: p = (p & 0b11111110) | (operand & 1);
                    operand >>= 1;
                    p = (p & 0b01111101) | (operand == 0 ? 2 : 0);
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x47: // SRE, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: cpuBus.write(address, operand);
              break;
            case 6: p = (p & 0b11111110) | (operand & 1);
                    operand >>= 1;
                    a ^= operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x48: // PHA
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2:
              break;
            case 3: cpuBus.write(s | 0x100, a);
              break;
            case 4: s = u8(s - 1);
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0x49: // EOR, imm
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    a ^= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x4A: // LSR, a
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: p = (p & 0b11111110) | (a & 1);
                    a >>= 1;
                    p = (p & 0b01111101) | (a == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x4B: // ALR, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    a &= operand;
                    p = (p & 0b11111110) | (a & 1);
                    a >>= 1;
                    p = (p & 0b01111101) | (a == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x4C: // JMP, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: abs(-1);
              break;
            case 4: pc = address;
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0x4D: // EOR, abs
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: a ^= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x4E: // LSR, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: p = (p & 0b11111110) | (operand & 1);
                    operand >>= 1;
                    p = (p & 0b01111101) | (operand == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x4F: // SRE, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: p = (p & 0b11111110) | (operand & 1);
                    operand >>= 1;
                    a ^= operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x50: // BVC, rel
          switch(subCycle) {
            case 0: incPC();
                    jump = ((p & 0x40) == 0);
              break;
            case 1: operand = cpuBus.read(pc);
                    if (jump) {
                      address = u16(i8(operand) + pc + 1);
                      boundaryCrossed = (address & 0xFF00) != (u16(pc + 1) & 0xFF00);
                      if (!boundaryCrossed) pollInterrupts();
                    } else {
                      pollInterrupts();
                    }
             break;
           case 2: incPC();
                   if (!jump) subCycle += 4;
             break;
           case 3: cpuBus.read(pc);
             break;
           case 4: writePCL(u8(address));
                   if (!boundaryCrossed) subCycle += 2;
             break;
           case 5: cpuBus.read(pc);
                   pollInterrupts();
             break;
           case 6: writePCH(address >> 8);
             break;
           case 7: fetch();
             break;
          }
          break;
          
        case 0x51: // EOR, ind, y
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYR(-1);
              break;
            case 10: a ^= operand;
                     p = (p & 0b01111101)
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x53: // SRE, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYRMW(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(pointer, operand);
              break;
            case 12: p = (p & 0b11111110) | (operand & 1);
                     operand >>= 1;
                     a ^= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 13: cpuBus.write(pointer, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0x55: // EOR, zpg, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: a ^= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x56: // LSR, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: p = (p & 0b11111110) | (operand & 1);
                    operand >>= 1;
                    p = (p & 0b01111101) | (operand == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x57: // SRE, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: p = (p & 0b11111110) | (operand & 1);
                    operand >>= 1;
                    a ^= operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x58: // CLI
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: p &= 0b11111011;
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x59: // EOR, abs, y
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYR(-1);
              break;
            case 8: a ^= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0x5B: // SRE, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: p = (p & 0b11111110) | (operand & 1);
                     operand >>= 1;
                     a ^= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x5D: // EOR, abs, x
          switch (subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXR(-1);
              break;
            case 8: a ^= operand;
                    p = (p & 0b01111101)
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0x5E: // LSR, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: p = (p & 0b11111110) | (operand & 1);
                     operand >>= 1;
                     p = (p & 0b01111101) | (operand == 0 ? 2 : 0);
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x5F: // SRE, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: p = (p & 0b11111110) | (operand & 1);
                     operand >>= 1;
                     a ^= operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x60: // RTS
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: operand = cpuBus.read(pc);
              break;
            case 2: incPC();
              break;
            case 3: operand = cpuBus.read(s | 0x100);
              break;
            case 4: break;
            
            case 5: writeTargetL(cpuBus.read(u8(s + 1) | 0x100));
              break;
            case 6: s = u8(s + 2);
              break;
            case 7: writeTargetH(cpuBus.read(s | 0x100));
              break;
            case 8: pc = target;
              break;
            case 9: operand = cpuBus.read(pc);
              break;
            case 10: incPC();
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x61: // ADC, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: result16 = a + operand + (p & 1);
                     p = (p & 0b10111111)
                     | (
                         (
                           (~(a ^ operand))
                           & ((a ^ result16) & 0x80)
                         ) != 0 ? 0x40 : 0
                       ); // all of this for the V flag...
                     a = u8(result16);
                     p = (p & 0b01111100) 
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (result16 & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x63: // RRA, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(address, operand);
              break;
            case 12: hiBit = u8(p << 7);
                     p = (p & 0b11111110) | (operand & 1);
                     operand = (operand >> 1) | hiBit;
                     result16 = a + operand + (p & 1);
                     p = (p & 0b10111111)
                     | (
                         (
                           (~(a ^ operand))
                           & ((a ^ result16) & 0x80)
                         ) != 0 ? 0x40 : 0
                       ); // all of this for the V flag...
                     a = u8(result16);
                     p = (p & 0b01111100) 
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (result16 & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 13: cpuBus.write(address, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0x65: // ADC, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: result16 = a + operand + (p & 1);
                     p = (p & 0b10111111)
                     | (
                         (
                           (~(a ^ operand))
                           & ((a ^ result16) & 0x80)
                         ) != 0 ? 0x40 : 0
                       ); // all of this for the V flag...
                     a = u8(result16);
                     p = (p & 0b01111100) 
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (result16 & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0x66: // ROR, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: cpuBus.write(address, operand);
              break;
            case 6: hiBit = u8(p << 7);
                    p = (p & 0b11111110) | (operand & 1);
                    operand = (operand >> 1) | hiBit;
                    p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x67: // RRA, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: cpuBus.write(address, operand);
              break;
            case 6: hiBit = u8(p << 7);
                    p = (p & 0b11111110) | (operand & 1);
                    operand = (operand >> 1) | hiBit;
                    result16 = a + operand + (p & 1);
                    p = (p & 0b10111111)
                    | (
                        (
                          (~(a ^ operand))
                          & ((a ^ result16) & 0x80)
                        ) != 0 ? 0x40 : 0
                      ); // all of this for the V flag...
                    a = u8(result16);
                    p = (p & 0b01111100) 
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (result16 & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x68: // PLA
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: break;
            
            case 3: operand = cpuBus.read(s | 0x100);
              break;
            case 4: s = u8(s + 1);
              break;
            case 5: operand = cpuBus.read(s | 0x100);
              break;
            case 6: a = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x69: // ADC, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    result16 = a + operand + (p & 1);
                    p = (p & 0b10111111)
                    | (
                        (
                          (~(a ^ operand))
                          & ((a ^ result16) & 0x80)
                        ) != 0 ? 0x40 : 0
                      ); // all of this for the V flag...
                    a = u8(result16);
                    p = (p & 0b01111100) 
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (result16 & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x6A: // ROR, a
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc); 
              break;
            case 2: hiBit = u8(p << 7);
                    p = (p & 0b11111110) | (a & 1);
                    a = u8(a >> 1) | hiBit;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x6B: // ARR, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: operand = cpuBus.read(pc);
              break;
            case 2: incPC();
                    a &= operand;
                    hiBit = u8(p << 7);
                    p = (p & 0b11111110) | (a >> 7); // C
                    a = (a >> 1) | hiBit;
                    p = (p & 0b00111101)
                    | (((p & 1) ^ ((a >> 5) & 1)) << 6) // V
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x6C: // JMP, ind
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: pointer = cpuBus.read(pc);
              break;
            case 2: incPC();
              break;
            case 3: writePointerH(cpuBus.read(pc));
              break;
            case 4: incPC();
              break;
            case 5: address = cpuBus.read(pointer);
              break;
            case 6: break;
              
            case 7: writeAddressH(cpuBus.read((pointer & 0xFF00) | u8(pointer + 1)));
              break;
            case 8: pc = address;
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0x6D: // ADC, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: result16 = a + operand + (p & 1);
                     p = (p & 0b10111111)
                     | (
                         (
                           (~(a ^ operand))
                           & ((a ^ result16) & 0x80)
                         ) != 0 ? 0x40 : 0
                       ); // all of this for the V flag...
                     a = u8(result16);
                     p = (p & 0b01111100) 
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (result16 & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x6E: // ROR, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: hiBit = u8(p << 7);
                    p = (p & 0b11111110) | (operand & 1);
                    operand = (operand >> 1) | hiBit;
                    p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x6F: // RRA, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: hiBit = u8(p << 7);
                    p = (p & 0b11111110) | (operand & 1);
                    operand = (operand >> 1) | hiBit;
                    result16 = a + operand + (p & 1);
                    p = (p & 0b10111111)
                    | (
                        (
                          (~(a ^ operand))
                          & ((a ^ result16) & 0x80)
                        ) != 0 ? 0x40 : 0
                      ); // all of this for the V flag...
                    a = u8(result16);
                    p = (p & 0b01111100) 
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (result16 & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x70: // BVS, rel
          switch(subCycle) {
            case 0: incPC();
                    jump = ((p & 0x40) == 0x40);
              break;
            case 1: operand = cpuBus.read(pc);
                    if (jump) {
                      address = u16(i8(operand) + pc + 1);
                      boundaryCrossed = (address & 0xFF00) != (u16(pc + 1) & 0xFF00);
                      if (!boundaryCrossed) pollInterrupts();
                    } else {
                      pollInterrupts();
                    }
             break;
           case 2: incPC();
                   if (!jump) subCycle += 4;
             break;
           case 3: cpuBus.read(pc);
             break;
           case 4: writePCL(u8(address));
                   if (!boundaryCrossed) subCycle += 2;
             break;
           case 5: cpuBus.read(pc);
                   pollInterrupts();
             break;
           case 6: writePCH(address >> 8);
             break;
           case 7: fetch();
             break;
          }
          break;
          
        case 0x71: // ADC, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYR(-1);
              break;
            case 10: result16 = a + operand + (p & 1);
                     p = (p & 0b10111111)
                     | (
                         (
                           (~(a ^ operand))
                           & ((a ^ result16) & 0x80)
                         ) != 0 ? 0x40 : 0
                       ); // all of this for the V flag...
                     a = u8(result16);
                     p = (p & 0b01111100) 
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (result16 & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0x73: // RRA, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYRMW(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(pointer, operand);
              break;
            case 12: hiBit = u8(p << 7);
                    p = (p & 0b11111110) | (operand & 1);
                    operand = (operand >> 1) | hiBit;
                    result16 = a + operand + (p & 1);
                    p = (p & 0b10111111)
                    | (
                        (
                          (~(a ^ operand))
                          & ((a ^ result16) & 0x80)
                        ) != 0 ? 0x40 : 0
                      ); // all of this for the V flag...
                    a = u8(result16);
                    p = (p & 0b01111100) 
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (result16 & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 13: cpuBus.write(pointer, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0x75: // ADC, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: result16 = a + operand + (p & 1);
                     p = (p & 0b10111111)
                     | (
                         (
                           (~(a ^ operand))
                           & ((a ^ result16) & 0x80)
                         ) != 0 ? 0x40 : 0
                       ); // all of this for the V flag...
                     a = u8(result16);
                     p = (p & 0b01111100) 
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (result16 & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0x76: // ROR, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: hiBit = u8(p << 7);
                    p = (p & 0b11111110) | (operand & 1);
                    operand = (operand >> 1) | hiBit;
                    p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x77: // RRA, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: hiBit = u8(p << 7);
                    p = (p & 0b11111110) | (operand & 1);
                    operand = (operand >> 1) | hiBit;
                    result16 = a + operand + (p & 1);
                    p = (p & 0b10111111)
                    | (
                        (
                          (~(a ^ operand))
                          & ((a ^ result16) & 0x80)
                        ) != 0 ? 0x40 : 0
                      ); // all of this for the V flag...
                    a = u8(result16);
                    p = (p & 0b01111100) 
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (result16 & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x78: // SEI
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: p |= 0b00000100;
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x79: // ADC, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYR(-1);
              break;
            case 8: result16 = a + operand + (p & 1);
                    p = (p & 0b10111111)
                    | (
                        (
                          (~(a ^ operand))
                          & ((a ^ result16) & 0x80)
                        ) != 0 ? 0x40 : 0
                      ); // all of this for the V flag...
                    a = u8(result16);
                    p = (p & 0b01111100) 
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (result16 & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0x7B: // RRA, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: hiBit = u8(p << 7);
                     p = (p & 0b11111110) | (operand & 1);
                     operand = (operand >> 1) | hiBit;
                     result16 = a + operand + (p & 1);
                     p = (p & 0b10111111)
                     | (
                         (
                           (~(a ^ operand))
                           & ((a ^ result16) & 0x80)
                         ) != 0 ? 0x40 : 0
                       ); // all of this for the V flag...
                     a = u8(result16);
                     p = (p & 0b01111100) 
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (result16 & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x7D: // ADC, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXR(-1);
              break;
            case 8: result16 = a + operand + (p & 1);
                    p = (p & 0b10111111)
                    | (
                        (
                          (~(a ^ operand))
                          & ((a ^ result16) & 0x80)
                        ) != 0 ? 0x40 : 0
                      ); // all of this for the V flag...
                    a = u8(result16);
                    p = (p & 0b01111100) 
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (result16 & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0x7E: // ROR, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: hiBit = u8(p << 7);
                     p = (p & 0b11111110) | (operand & 1);
                     operand = (operand >> 1) | hiBit;
                     p = (p & 0b01111101) | (operand & 0x80) | (operand == 0 ? 2 : 0);
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x7F: // RRA, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: hiBit = u8(p << 7);
                     p = (p & 0b11111110) | (operand & 1);
                     operand = (operand >> 1) | hiBit;
                     result16 = a + operand + (p & 1);
                     p = (p & 0b10111111)
                     | (
                         (
                           (~(a ^ operand))
                           & ((a ^ result16) & 0x80)
                         ) != 0 ? 0x40 : 0
                       ); // all of this for the V flag...
                     a = u8(result16);
                     p = (p & 0b01111100) 
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (result16 & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0x81: // STA, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8: indXR(-1);
              break;
            case 9: cpuBus.write(address, a);
              break;
            case 10: break;
              
            case 11: fetch();
              break;
          }
          break;
          
        case 0x83: // SAX, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8: indXR(-1);
              break;
            case 9: cpuBus.write(address, a & x);
              break;
            case 10: break;
              
            case 11: fetch();
              break;
          }
          break;
          
        case 0x84: // STY, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2: zpg(-1);
              break;
            case 3: cpuBus.write(address, y);
              break;
            case 4: break;
            
            case 5: fetch();
              break;
          }
          break;
          
        case 0x85: // STA, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2: zpg(-1);
              break;
            case 3: cpuBus.write(address, a);
              break;
            case 4: break;
            
            case 5: fetch();
              break;
          }
          break;
          
        case 0x86: // STX, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2: zpg(-1);
              break;
            case 3: cpuBus.write(address, x);
              break;
            case 4: break;
            
            case 5: fetch();
              break;
          }
          break;
          
        case 0x87: // SAX, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2: zpg(-1);
              break;
            case 3: cpuBus.write(address, a & x);
              break;
            case 4: break;
            
            case 5: fetch();
              break;
          }
          break;
          
        case 0x88: // DEY
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: y = u8(y - 1);
                    p = (p & 0b01111101) | (y & 0x80) | (y == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x8A: // TXA
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: a = x;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x8B: // ANE, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    a = ((a | MAGIC) & x & operand);
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x8C: // STY, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4: abs(-1);
              break;
            case 5: cpuBus.write(address, y);
              break;
            case 6: break;
            
            case 7: fetch();
              break;
          }
          break;
          
        case 0x8D: // STA, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4: abs(-1);
              break;
            case 5: cpuBus.write(address, a);
              break;
            case 6: break;
            
            case 7: fetch();
              break;
          }
          break;
          
        case 0x8E: // STX, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4: abs(-1);
              break;
            case 5: cpuBus.write(address, x);
              break;
            case 6: break;
            
            case 7: fetch();
              break;
          }
          break;
          
        case 0x8F: // SAX, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4: abs(-1);
              break;
            case 5: cpuBus.write(address, a & x);
              break;
            case 6: break;
            
            case 7: fetch();
              break;
          }
          break;
          
        case 0x90: // BCC, rel
          switch(subCycle) {
            case 0: incPC();
                    jump = ((p & 1) == 0);
              break;
            case 1: operand = cpuBus.read(pc);
                    if (jump) {
                      address = u16(i8(operand) + pc + 1);
                      boundaryCrossed = (address & 0xFF00) != (u16(pc + 1) & 0xFF00);
                      if (!boundaryCrossed) pollInterrupts();
                    } else {
                      pollInterrupts();
                    }
             break;
           case 2: incPC();
                   if (!jump) subCycle += 4;
             break;
           case 3: cpuBus.read(pc);
             break;
           case 4: writePCL(u8(address));
                   if (!boundaryCrossed) subCycle += 2;
             break;
           case 5: cpuBus.read(pc);
                   pollInterrupts();
             break;
           case 6: writePCH(address >> 8);
             break;
           case 7: fetch();
             break;
          }
          break;
          
        case 0x91: // STA, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8: indYRMW(-1);
              break;
            case 9: cpuBus.write(pointer, a);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x93: // SHA, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8: indYRMW(-1);
              break;
            case 9: high = pointer >> 8;
                    if (!boundaryCrossed) high = u16(high + 1);
                    // if (RDYlow) high = 0xFFFF; NOT IMPLEMENTED
                    val = u8(high & a & x);
                    if (boundaryCrossed) {
                      cpuBus.write(u8(pointer) | (val << 8), val);
                    } else {
                      cpuBus.write(pointer, val);
                    }
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0x94: // STY, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4: zpgX(-1);
              break;
            case 5: cpuBus.write(address, y);
              break;
            case 6: break;
            
            case 7: fetch();
              break;
          }
          break;
          
        case 0x95: // STA, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4: zpgX(-1);
              break;
            case 5: cpuBus.write(address, a);
              break;
            case 6: break;
            
            case 7: fetch();
              break;
          }
          break;
          
        case 0x96: // STX, zpg, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4: zpgY(-1);
              break;
            case 5: cpuBus.write(address, x);
              break;
            case 6: break;
            
            case 7: fetch();
              break;
          }
          break;
          
        case 0x97: // SAX, zpg, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4: zpgY(-1);
              break;
            case 5: cpuBus.write(address, a & x);
              break;
            case 6: break;
            
            case 7: fetch();
              break;
          }
          break;
          
        case 0x98: // TYA
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: a = y;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x99: // STA, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6: absYRMW(-1);
              break;
            case 7: cpuBus.write(address, a);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x9A: // TXS
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: s = x;
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0x9B: // TAS, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6: absYRMW(-1);
              break;
            case 7: if (boundaryCrossed) {
                      val = u8((address >> 8) & a & x);
                      cpuBus.write(u8(address) | (val << 8), val);
                    } else {
                      val = u8(u8((address >> 8) + 1) & a & x);
                      cpuBus.write(address, val);
                    }
                    
                    s = a & x;
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x9C: // SHY, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6: absXRMW(-1);
              break;
            case 7: if (boundaryCrossed) {
                      val = u8((address >> 8) & y);
                      cpuBus.write(u8(address) | (val << 8), val);
                    } else {
                      val = u8(u8((address >> 8) + 1) & y);
                      cpuBus.write(address, val);
                    }
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x9D: // STA, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6: absXRMW(-1);
              break;
            case 7: cpuBus.write(address, a);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x9E: // SHX, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6: absYRMW(-1);
              break;
            case 7: if (boundaryCrossed) {
                      val = u8((address >> 8) & x);
                      cpuBus.write(u8(address) | (val << 8), val);
                    } else {
                      val = u8(u8((address >> 8) + 1) & x);
                      cpuBus.write(address, val);
                    }
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0x9F: // SHA, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6: absYRMW(-1);
              break;
            case 7: high = address >> 8;
                    if (!boundaryCrossed) high = u16(high + 1);
                    // if (RDYlow) high = 0xFFFF; NOT IMPLEMENTED
                    val = u8(high & a & x);
                    if (boundaryCrossed) {
                      cpuBus.write(u8(address) | (val << 8), val);
                    } else {
                      cpuBus.write(address, val);
                    }
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0xA0: // LDY, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    y = operand;
                    p = (p & 0b01111101) | (y & 0x80) | (y == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xA1: // LDA, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: a = operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0xA2: // LDX, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    x = operand;
                    p = (p & 0b01111101) | (x & 0x80) | (x == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xA3: // LAX, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: a = x = operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0xA4: // LDY, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: y = operand;
                    p = (p & 0b01111101) | (y & 0x80) | (y == 0 ? 2 : 0);
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0xA5: // LDA, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: a = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0xA6: // LDX, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: x = operand;
                    p = (p & 0b01111101) | (x & 0x80) | (x == 0 ? 2 : 0);
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0xA7: // LAX, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: a = x = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0xA8: // TAY
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: y = a;
                    p = (p & 0b01111101) | (y & 0x80) | (y == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xA9: // LDA, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    a = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xAA: // TAX
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: x = a;
                    p = (p & 0b01111101) | (x & 0x80) | (x == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xAB: // LXA, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    a = x = ((a | MAGIC) & operand);
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xAC: // LDY, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: y = operand;
                    p = (p & 0b01111101) | (y & 0x80) | (y == 0 ? 2 : 0);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xAD: // LDA, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: a = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xAE: // LDX, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: x = operand;
                    p = (p & 0b01111101) | (x & 0x80) | (x == 0 ? 2 : 0);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xAF: // LAX, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: a = x = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xB0: // BCS, rel
          switch(subCycle) {
            case 0: incPC();
                    jump = ((p & 1) == 1);
              break;
            case 1: operand = cpuBus.read(pc);
                    if (jump) {
                      address = u16(i8(operand) + pc + 1);
                      boundaryCrossed = (address & 0xFF00) != (u16(pc + 1) & 0xFF00);
                      if (!boundaryCrossed) pollInterrupts();
                    } else {
                      pollInterrupts();
                    }
             break;
           case 2: incPC();
                   if (!jump) subCycle += 4;
             break;
           case 3: cpuBus.read(pc);
             break;
           case 4: writePCL(u8(address));
                   if (!boundaryCrossed) subCycle += 2;
             break;
           case 5: cpuBus.read(pc);
                   pollInterrupts();
             break;
           case 6: writePCH(address >> 8);
             break;
           case 7: fetch();
             break;
          }
          break;
          
        case 0xB1: // LDA, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYR(-1);
              break;
            case 10: a = operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0xB3: // LAX, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYR(-1);
              break;
            case 10: a = x = operand;
                     p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0xB4: // LDY, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: y = operand;
                    p = (p & 0b01111101) | (y & 0x80) | (y == 0 ? 2 : 0);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xB5: // LDA, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: a = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xB6: // LDX, zpg, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgY(-1);
              break;
            case 6: x = operand;
                    p = (p & 0b01111101) | (x & 0x80) | (x == 0 ? 2 : 0);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xB7: // LAX, zpg, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgY(-1);
              break;
            case 6: a = x = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xB8: // CLV
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: p &= 0b10111111;
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xB9: // LDA, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYR(-1);
              break;
            case 8: a = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0xBA: // TSX
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: x = s;
                    p = (p & 0b01111101) | (x & 0x80) | (x == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xBB: // LAS, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYR(-1);
              break;
            case 8: a = x = s = (operand & s);
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0xBC: // LDY, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXR(-1);
              break;
            case 8: y = operand;
                    p = (p & 0b01111101) | (y & 0x80) | (y == 0 ? 2 : 0);
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0xBD: // LDA, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXR(-1);
              break;
            case 8: a = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0xBE: // LDX, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYR(-1);
              break;
            case 8: x = operand;
                    p = (p & 0b01111101) | (x & 0x80) | (x == 0 ? 2 : 0);
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0xBF: // LAX, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYR(-1);
              break;
            case 8: a = x = operand;
                    p = (p & 0b01111101) | (a & 0x80) | (a == 0 ? 2 : 0);
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0xC0: // CPY, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    p = (p & 0b01111100)
                    | (y >= operand ? 1 : 0) // C
                    | ((y - operand) & 0x80) // N
                    | (y == operand ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xC1: // CMP, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: p = (p & 0b01111100)
                     | (a >= operand ? 1 : 0) // C
                     | ((a - operand) & 0x80) // N
                     | (a == operand ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0xC3: // DCP, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(address, operand);
              break;
            case 12: operand = u8(operand - 1);
                     p = (p & 0b01111100)
                     | (a >= operand ? 1 : 0) // C
                     | ((a - operand) & 0x80) // N
                     | (a == operand ? 2 : 0); // Z
              break;
            case 13: cpuBus.write(address, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0xC4: // CPY, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: p = (p & 0b01111100)
                    | (y >= operand ? 1 : 0) // C
                    | ((y - operand) & 0x80) // N
                    | (y == operand ? 2 : 0); // Z
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0xC5: // CMP, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: p = (p & 0b01111100)
                    | (a >= operand ? 1 : 0) // C
                    | ((a - operand) & 0x80) // N
                    | (a == operand ? 2 : 0); // Z
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0xC6: // DEC, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
              
            case 5: cpuBus.write(address, operand);
              break;
            case 6: operand = u8(operand - 1);
                    p = (p & 0b01111101)
                    | (operand & 0x80) // N
                    | (operand == 0 ? 2 : 0); // Z
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0xC7: // DCP, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: cpuBus.write(address, operand);
              break;
            case 6: operand = u8(operand - 1);
                    p = (p & 0b01111100)
                    | (a >= operand ? 1 : 0) // C
                    | ((a - operand) & 0x80) // N
                    | (a == operand ? 2 : 0); // Z
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0xC8: // INY
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: y = u8(y + 1);
                    p = (p & 0b01111101) | (y & 0x80) | (y == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xC9: // CMP, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    p = (p & 0b01111100)
                    | (a >= operand ? 1 : 0) // C
                    | ((a - operand) & 0x80) // N
                    | (a == operand ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xCA: // DEX
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: x = u8(x - 1);
                    p = (p & 0b01111101) | (x & 0x80) | (x == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xCB: // SBX, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    anx = a & x;
                    p = (p & 0b11111110) | (anx >= operand ? 1 : 0);
                    x = u8(anx - operand);
                    p = (p & 0b01111101) | (x & 0x80) | (x == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xCC: // CPY, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: p = (p & 0b01111100)
                    | (y >= operand ? 1 : 0) // C
                    | ((y - operand) & 0x80) // N
                    | (y == operand ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xCD: // CMP, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: p = (p & 0b01111100)
                    | (a >= operand ? 1 : 0) // C
                    | ((a - operand) & 0x80) // N
                    | (a == operand ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xCE: // DEC, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
              
            case 7: cpuBus.write(address, operand);
              break;
            case 8: operand = u8(operand - 1);
                    p = (p & 0b01111101)
                    | (operand & 0x80) // N
                    | (operand == 0 ? 2 : 0); // Z
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0xCF: // DCP, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: operand = u8(operand - 1);
                    p = (p & 0b01111100)
                    | (a >= operand ? 1 : 0) // C
                    | ((a - operand) & 0x80) // N
                    | (a == operand ? 2 : 0); // Z
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0xD0: // BNE, rel
          switch(subCycle) {
            case 0: incPC();
                    jump = ((p & 2) == 0);
              break;
            case 1: operand = cpuBus.read(pc);
                    if (jump) {
                      address = u16(i8(operand) + pc + 1);
                      boundaryCrossed = (address & 0xFF00) != (u16(pc + 1) & 0xFF00);
                      if (!boundaryCrossed) pollInterrupts();
                    } else {
                      pollInterrupts();
                    }
             break;
           case 2: incPC();
                   if (!jump) subCycle += 4;
             break;
           case 3: cpuBus.read(pc);
             break;
           case 4: writePCL(u8(address));
                   if (!boundaryCrossed) subCycle += 2;
             break;
           case 5: cpuBus.read(pc);
                   pollInterrupts();
             break;
           case 6: writePCH(address >> 8);
             break;
           case 7: fetch();
             break;
          }
          break;
          
        case 0xD1: // CMP, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYR(-1);
              break;
            case 10: p = (p & 0b01111100)
                     | (a >= operand ? 1 : 0) // C
                     | ((a - operand) & 0x80) // N
                     | (a == operand ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0xD3: // DCP, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYRMW(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(pointer, operand);
              break;
            case 12: operand = u8(operand - 1);
                     p = (p & 0b01111100)
                     | (a >= operand ? 1 : 0) // C
                     | ((a - operand) & 0x80) // N
                     | (a == operand ? 2 : 0); // Z
              break;
            case 13: cpuBus.write(pointer, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0xD5: // CMP, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: p = (p & 0b01111100)
                    | (a >= operand ? 1 : 0) // C
                    | ((a - operand) & 0x80) // N
                    | (a == operand ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xD6: // DEC, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
              
            case 7: cpuBus.write(address, operand);
              break;
            case 8: operand = u8(operand - 1);
                    p = (p & 0b01111101)
                    | (operand & 0x80) // N
                    | (operand == 0 ? 2 : 0); // Z
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0xD7: // DCP, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: operand = u8(operand - 1);
                    p = (p & 0b01111100)
                    | (a >= operand ? 1 : 0) // C
                    | ((a - operand) & 0x80) // N
                    | (a == operand ? 2 : 0); // Z
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0xD8: // CLD
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: p &= 0b11110111;
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xD9: // CMP, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYR(-1);
              break;
            case 8: p = (p & 0b01111100)
                    | (a >= operand ? 1 : 0) // C
                    | ((a - operand) & 0x80) // N
                    | (a == operand ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0xDB: // DCP, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: operand = u8(operand - 1);
                     p = (p & 0b01111100)
                     | (a >= operand ? 1 : 0) // C
                     | ((a - operand) & 0x80) // N
                     | (a == operand ? 2 : 0); // Z
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0xDD: // CMP, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXR(-1);
              break;
            case 8: p = (p & 0b01111100)
                    | (a >= operand ? 1 : 0) // C
                    | ((a - operand) & 0x80) // N
                    | (a == operand ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0xDE: // DEC, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
              
            case 9: cpuBus.write(address, operand);
              break;
            case 10: operand = u8(operand - 1);
                    p = (p & 0b01111101)
                    | (operand & 0x80) // N
                    | (operand == 0 ? 2 : 0); // Z
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0xDF: // DCP, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: operand = u8(operand - 1);
                     p = (p & 0b01111100)
                     | (a >= operand ? 1 : 0) // C
                     | ((a - operand) & 0x80) // N
                     | (a == operand ? 2 : 0); // Z
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0xE0: // CPX, imm
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    p = (p & 0b01111100)
                    | (x >= operand ? 1 : 0) // C
                    | ((x - operand) & 0x80) // N
                    | (x == operand ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xE1: // SBC, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: val = operand ^ 0xFF;
                     result16 = a + val + (p & 1);
                     p = (p & 0b10111111) 
                     | (
                         (
                           (a ^ result16)
                           & (val ^ result16)
                           & 0x80
                         )
                         != 0 ? 0x40 : 0
                       );
                     a = u8(result16);
                     p = (p & 0b01111100)
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0xE3: // ISC, ind, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indXR(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(address, operand);
              break;
            case 12: operand = u8(operand + 1);
                     val = operand ^ 0xFF;
                     result16 = a + val + (p & 1);
                     p = (p & 0b10111111) 
                     | (
                         (
                           (a ^ result16)
                           & (val ^ result16)
                           & 0x80
                         )
                         != 0 ? 0x40 : 0
                       );
                     a = u8(result16);
                     p = (p & 0b01111100)
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 13: cpuBus.write(address, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0xE4: // CPX, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: p = (p & 0b01111100)
                    | (x >= operand ? 1 : 0) // C
                    | ((x - operand) & 0x80) // N
                    | (x == operand ? 2 : 0); // Z
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0xE5: // SBC, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: val = operand ^ 0xFF;
                    result16 = a + val + (p & 1);
                    p = (p & 0b10111111) 
                    | (
                        (
                          (a ^ result16)
                          & (val ^ result16)
                          & 0x80
                        )
                        != 0 ? 0x40 : 0
                      );
                    a = u8(result16);
                    p = (p & 0b01111100)
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 5: fetch();
              break;
          }
          break;
          
        case 0xE6: // INC, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
              
            case 5: cpuBus.write(address, operand);
              break;
            case 6: operand = u8(operand + 1);
                    p = (p & 0b01111101)
                    | (operand & 0x80) // N
                    | (operand == 0 ? 2 : 0); // Z
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0xE7: // ISC, zpg
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3: zpg(-1);
              break;
            case 4: break;
            
            case 5: cpuBus.write(address, operand);
              break;
            case 6: operand = u8(operand + 1);
                    val = operand ^ 0xFF;
                    result16 = a + val + (p & 1);
                    p = (p & 0b10111111) 
                    | (
                        (
                          (a ^ result16)
                          & (val ^ result16)
                          & 0x80
                        )
                        != 0 ? 0x40 : 0
                      );
                    a = u8(result16);
                    p = (p & 0b01111100)
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 7: cpuBus.write(address, operand);
              break;
            case 8: break;
            
            case 9: fetch();
              break;
          }
          break;
          
        case 0xE8: // INX
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: x = u8(x + 1);
                    p = (p & 0b01111101) | (x & 0x80) | (x == 0 ? 2 : 0);
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xE9: // SBC, imm
        case 0xEB:
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: imm(-1);
              break;
            case 2: incPC();
                    val = operand ^ 0xFF;
                    result16 = a + val + (p & 1);
                    p = (p & 0b10111111) 
                    | (
                        (
                          (a ^ result16)
                          & (val ^ result16)
                          & 0x80
                        )
                        != 0 ? 0x40 : 0
                      );
                    a = u8(result16);
                    p = (p & 0b01111100)
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xEC: // CPX, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: p = (p & 0b01111100)
                    | (x >= operand ? 1 : 0) // C
                    | ((x - operand) & 0x80) // N
                    | (x == operand ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xED: // SBC, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: val = operand ^ 0xFF;
                    result16 = a + val + (p & 1);
                    p = (p & 0b10111111) 
                    | (
                        (
                          (a ^ result16)
                          & (val ^ result16)
                          & 0x80
                        )
                        != 0 ? 0x40 : 0
                      );
                    a = u8(result16);
                    p = (p & 0b01111100)
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xEE: // INC, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
              
            case 7: cpuBus.write(address, operand);
              break;
            case 8: operand = u8(operand + 1);
                    p = (p & 0b01111101)
                    | (operand & 0x80) // N
                    | (operand == 0 ? 2 : 0); // Z
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0xEF: // ISC, abs
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: abs(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: operand = u8(operand + 1);
                    val = operand ^ 0xFF;
                    result16 = a + val + (p & 1);
                    p = (p & 0b10111111) 
                    | (
                        (
                          (a ^ result16)
                          & (val ^ result16)
                          & 0x80
                        )
                        != 0 ? 0x40 : 0
                      );
                    a = u8(result16);
                    p = (p & 0b01111100)
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0xF0: // BEQ, rel
          switch(subCycle) {
            case 0: incPC();
                    jump = ((p & 2) == 2);
              break;
            case 1: operand = cpuBus.read(pc);
                    if (jump) {
                      address = u16(i8(operand) + pc + 1);
                      boundaryCrossed = (address & 0xFF00) != (u16(pc + 1) & 0xFF00);
                      if (!boundaryCrossed) pollInterrupts();
                    } else {
                      pollInterrupts();
                    }
             break;
           case 2: incPC();
                   if (!jump) subCycle += 4;
             break;
           case 3: cpuBus.read(pc);
             break;
           case 4: writePCL(u8(address));
                   if (!boundaryCrossed) subCycle += 2;
             break;
           case 5: cpuBus.read(pc);
                   pollInterrupts();
             break;
           case 6: writePCH(address >> 8);
             break;
           case 7: fetch();
             break;
          }
          break;
          
        case 0xF1: // SBC, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYR(-1);
              break;
            case 10: val = operand ^ 0xFF;
                     result16 = a + val + (p & 1);
                     p = (p & 0b10111111) 
                     | (
                         (
                           (a ^ result16)
                           & (val ^ result16)
                           & 0x80
                         )
                         != 0 ? 0x40 : 0
                       );
                     a = u8(result16);
                     p = (p & 0b01111100)
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: fetch();
              break;
          }
          break;
          
        case 0xF3: // ISC, ind, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9: indYRMW(-1);
              break;
            case 10: break;
            
            case 11: cpuBus.write(pointer, operand);
              break;
            case 12: operand = u8(operand + 1);
                     val = operand ^ 0xFF;
                     result16 = a + val + (p & 1);
                     p = (p & 0b10111111) 
                     | (
                         (
                           (a ^ result16)
                           & (val ^ result16)
                           & 0x80
                         )
                         != 0 ? 0x40 : 0
                       );
                     a = u8(result16);
                     p = (p & 0b01111100)
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 13: cpuBus.write(pointer, operand);
              break;
            case 14: break;
            
            case 15: fetch();
              break;
          }
          break;
          
        case 0xF5: // SBC, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: val = operand ^ 0xFF;
                    result16 = a + val + (p & 1);
                    p = (p & 0b10111111) 
                    | (
                        (
                          (a ^ result16)
                          & (val ^ result16)
                          & 0x80
                        )
                        != 0 ? 0x40 : 0
                      );
                    a = u8(result16);
                    p = (p & 0b01111100)
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 7: fetch();
              break;
          }
          break;
          
        case 0xF6: // INC, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
              
            case 7: cpuBus.write(address, operand);
              break;
            case 8: operand = u8(operand + 1);
                    p = (p & 0b01111101)
                    | (operand & 0x80) // N
                    | (operand == 0 ? 2 : 0); // Z
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0xF7: // ISC, zpg, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5: zpgX(-1);
              break;
            case 6: break;
            
            case 7: cpuBus.write(address, operand);
              break;
            case 8: operand = u8(operand + 1);
                    val = operand ^ 0xFF;
                    result16 = a + val + (p & 1);
                    p = (p & 0b10111111) 
                    | (
                        (
                          (a ^ result16)
                          & (val ^ result16)
                          & 0x80
                        )
                        != 0 ? 0x40 : 0
                      );
                    a = u8(result16);
                    p = (p & 0b01111100)
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: cpuBus.write(address, operand);
              break;
            case 10: break;
            
            case 11: fetch();
              break;
          }
          break;
          
        case 0xF8: // SED
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1: cpuBus.read(pc);
              break;
            case 2: p |= 0b00001000;
              break;
            case 3: fetch();
              break;
          }
          break;
          
        case 0xF9: // SBC, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYR(-1);
              break;
            case 8: val = operand ^ 0xFF;
                    result16 = a + val + (p & 1);
                    p = (p & 0b10111111) 
                    | (
                        (
                          (a ^ result16)
                          & (val ^ result16)
                          & 0x80
                        )
                        != 0 ? 0x40 : 0
                      );
                    a = u8(result16);
                    p = (p & 0b01111100)
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0xFB: // ISC, abs, y
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absYRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: operand = u8(operand + 1);
                     val = operand ^ 0xFF;
                     result16 = a + val + (p & 1);
                     p = (p & 0b10111111) 
                     | (
                         (
                           (a ^ result16)
                           & (val ^ result16)
                           & 0x80
                         )
                         != 0 ? 0x40 : 0
                       );
                     a = u8(result16);
                     p = (p & 0b01111100)
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0xFD: // SBC, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXR(-1);
              break;
            case 8: val = operand ^ 0xFF;
                    result16 = a + val + (p & 1);
                    p = (p & 0b10111111) 
                    | (
                        (
                          (a ^ result16)
                          & (val ^ result16)
                          & 0x80
                        )
                        != 0 ? 0x40 : 0
                      );
                    a = u8(result16);
                    p = (p & 0b01111100)
                    | (result16 > 0xFF ? 1 : 0) // C
                    | (a & 0x80) // N
                    | (a == 0 ? 2 : 0); // Z
              break;
            case 9: fetch();
              break;
          }
          break;
          
        case 0xFE: // INC, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
              
            case 9: cpuBus.write(address, operand);
              break;
            case 10: operand = u8(operand + 1);
                    p = (p & 0b01111101)
                    | (operand & 0x80) // N
                    | (operand == 0 ? 2 : 0); // Z
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        case 0xFF: // ISC, abs, x
          switch(subCycle) {
            case 0: incPC();
              break;
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7: absXRMW(-1);
              break;
            case 8: break;
            
            case 9: cpuBus.write(address, operand);
              break;
            case 10: operand = u8(operand + 1);
                     val = operand ^ 0xFF;
                     result16 = a + val + (p & 1);
                     p = (p & 0b10111111) 
                     | (
                         (
                           (a ^ result16)
                           & (val ^ result16)
                           & 0x80
                         )
                         != 0 ? 0x40 : 0
                       );
                     a = u8(result16);
                     p = (p & 0b01111100)
                     | (result16 > 0xFF ? 1 : 0) // C
                     | (a & 0x80) // N
                     | (a == 0 ? 2 : 0); // Z
              break;
            case 11: cpuBus.write(address, operand);
              break;
            case 12: break;
            
            case 13: fetch();
              break;
          }
          break;
          
        default: unimplemented = true;
          break;
      }
    } else {
      nmi();
    }
    
    subCycle += 1;
  }
  
  // functions to abstract certain cpu functions
  void incPC() {
    pc = u16(pc + 1);
  }
  
  // addressing modes
  void imm(int offset) { // imm addressing
    switch(subCycle + offset) {
      case 0: operand = cpuBus.read(pc);
        break;
    }
  }
  
  void zpg(int offset) { // zpg addressing
    switch(subCycle + offset) {
      case 0: address = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: operand = cpuBus.read(address);
        break;
    }
  }
  
  void zpgX(int offset) { // zpg X addressing
    switch(subCycle + offset) {
      case 0: pointer = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: operand = cpuBus.read(pointer);
        break;
      case 3: address = u8(pointer + x);
        break;
      case 4: operand = cpuBus.read(address);
        break;
    }
  }
  
  void zpgY(int offset) { // zpg Y addressing
    switch(subCycle + offset) {
      case 0: pointer = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: operand = cpuBus.read(pointer);
        break;
      case 3: target = pointer + y;
              address = target & 0xFF;
              writeAddressH(pointer >> 8);
        break;
      case 4: operand = cpuBus.read(address);
        break;
    }
  }
  
  void abs(int offset) { // abs addressing
    switch(subCycle + offset) {
      case 0: address = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: writeAddressH(cpuBus.read(pc));
        break;
      case 3: incPC();
        break;
      case 4: operand = cpuBus.read(address);
        break;
    }
  }
  
  void absYR(int offset) { // abs Y addressing (Read only)
    switch(subCycle + offset) {
      case 0: pointer = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: writePointerH(cpuBus.read(pc));
        break;
      case 3: incPC();
              target = u16(pointer + y);
              writeAddressL(u8(target));
              writeAddressH(pointer >> 8);
              boundaryCrossed = pointer >> 8 != target >> 8;
        break;
      case 4: operand = cpuBus.read(address);
              if (!boundaryCrossed) subCycle += 2;
        break;
      case 5: writeAddressH(target >> 8);
        break;
      case 6: operand = cpuBus.read(address);
        break;
    }
  }
  
  void absYRMW(int offset) { // abs Y addressing (Read Modify Write)
    switch(subCycle + offset) {
      case 0: pointer = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: writePointerH(cpuBus.read(pc));
        break;
      case 3: incPC();
              target = u16(pointer + y);
              writeAddressL(u8(target));
              writeAddressH(pointer >> 8);
              boundaryCrossed = pointer >> 8 != target >> 8;
        break;
      case 4: operand = cpuBus.read(address);
        break;
      case 5: writeAddressH(target >> 8);
        break;
      case 6: operand = cpuBus.read(address);
        break;
    }
  }
  
  void absXR(int offset) { // abs X addressing (Read only)
    switch(subCycle + offset) {
      case 0: pointer = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: writePointerH(cpuBus.read(pc));
        break;
      case 3: incPC();
              target = u16(pointer + x);
              writeAddressL(u8(target));
              writeAddressH(pointer >> 8);
              boundaryCrossed = pointer >> 8 != target >> 8;
        break;
      case 4: operand = cpuBus.read(address);
              if (!boundaryCrossed) subCycle += 2;
        break;
      case 5: writeAddressH(target >> 8);
        break;
      case 6: operand = cpuBus.read(address);
        break;
    }
  }
  
  void absXRMW(int offset) { // abs X addressing (Read Modify Write)
    switch(subCycle + offset) {
      case 0: pointer = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: writePointerH(cpuBus.read(pc));
        break;
      case 3: incPC();
              target = u16(pointer + x);
              writeAddressL(u8(target));
              writeAddressH(pointer >> 8);
              boundaryCrossed = pointer >> 8 != target >> 8;
        break;
      case 4: operand = cpuBus.read(address);
        break;
      case 5: writeAddressH(target >> 8);
        break;
      case 6: operand = cpuBus.read(address);
        break;
    }
  }
  
  void indYR(int offset) { // indirect Y addressing (Read only)
    switch(subCycle + offset) {
      case 0: pointer = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: address = cpuBus.read(pointer);
        break;
      case 3: break;
      
      case 4: writeAddressH(cpuBus.read(u8(pointer + 1)));
        break;
      case 5: target = address + y;
              writePointerL(u8(target));
              writePointerH(address >> 8);
              boundaryCrossed = u8(pointer >> 8) != u8(target >> 8);
        break;
      case 6: operand = cpuBus.read(pointer);
              if (!boundaryCrossed) subCycle += 2;
        break;
      case 7: writePointerH(u8(target >> 8));
        break;
      case 8: operand = cpuBus.read(pointer);
        break;
    }
  }
  
  void indYRMW(int offset) { // indirect Y addressing (Read Modify Write)
    switch(subCycle + offset) {
      case 0: pointer = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: address = cpuBus.read(pointer);
        break;
      case 3: break;
      
      case 4: writeAddressH(cpuBus.read(u8(pointer + 1)));
        break;
      case 5: target = address + y;
              writePointerL(u8(target));
              writePointerH(address >> 8);
              boundaryCrossed = u8(pointer >> 8) != u8(target >> 8);
        break;
      case 6: operand = cpuBus.read(pointer);
        break;
      case 7: writePointerH(u8(target >> 8));
        break;
      case 8: operand = cpuBus.read(pointer);
        break;
    }
  }
  
  void indXR(int offset) { // indirect X addressing
    switch(subCycle + offset) {
      case 0: operand = cpuBus.read(pc);
        break;
      case 1: incPC();
        break;
      case 2: cpuBus.read(operand);
        break;
      case 3: pointer = u8(operand + x);
        break;
      case 4: address = cpuBus.read(pointer);
        break;
      case 5: break;
      
      case 6: writeAddressH(cpuBus.read(u8(pointer + 1)));
        break;
      case 7: break;
        
      case 8: operand = cpuBus.read(address);
        break;
    }
  }
  
  // specific to opcodes...
  void jam() {
    switch(subCycle) {
        case 0: incPC();
          break;
        case 1: cpuBus.read(pc);
          break;
        case 2: break;
        
        case 3: cpuBus.read(0xFFFF);
          break;
        case 4: break;
        
        case 5: cpuBus.read(0xFFFE);
          break;
        case 6: break;
        
        case 7: cpuBus.read(0xFFFE);
                jammed = true;
          break;
        case 8: cpuBus.read(0xFFFF);
          break;
        case 9: subCycle -= 3;
          break;
      }
  }
  
  // functions for bitwise stuff
  int u8(int value) {
    return value & 0xFF;
  }
  
  int u16(int value) {
    return value & 0xFFFF;
  }
  
  int i8(int value) {
    return value << 24 >> 24;
  }
  
  // functions for bits of certain registers
  void writePCH(int value) {
    pc = u8(pc) | u8(value) << 8;
  }
  
  void writePCL(int value) {
    pc = u8(pc >> 8) << 8 | u8(value);
  }
  
  void writeAddressH(int value) {
    address = u8(address) | u8(value) << 8;
  }
  
  void writeAddressL(int value) {
    address = u8(address >> 8) << 8 | u8(value);
  }
  
  void writePointerH(int value) {
    pointer = u8(pointer) | u8(value) << 8;
  }
  
  void writePointerL(int value) {
    pointer = u8(pointer >> 8) << 8 | u8(value);
  }
  
  void writeTargetH(int value) {
    target = u8(target) | u8(value) << 8;
  }
  
  void writeTargetL(int value) {
    target = u8(target >> 8) << 8 | u8(value);
  }
  
  void fetch() {
    opCode = cpuBus.read(pc);
    subCycle = -1;
    
    if (waitingNMI) {
      runningNMI = true;
      waitingNMI = false;
    }
  }
  
  // interrupt handler
  void pollInterrupts() {
    if (!ppu.hitNmi) {
      if (ppu.ppuStatus >> 7 > 0) {
        if (ppu.ppuCtrl >> 7 > 0) {
          waitingNMI = true;
        }
      }
    }
  }
  
  void nmi() {
    switch(subCycle) {
      case 0: ppu.hitNmi = true;
        break;
      case 1: cpuBus.read(pc);
        break;
      case 2: break;
      
      case 3: cpuBus.write(s | 0x100, u8(pc >> 8));
        break;
      case 4: break;
      
      case 5: cpuBus.write(u8(s - 1) | 0x100, u8(pc));
        break;
      case 6: vector = vectors[1];
        break;
      case 7: cpuBus.write(u8(s - 2) | 0x100, p | 0b00100000);
        break;
      case 8: s = u8(s - 3);
        break;
      case 9: writeAddressL(cpuBus.read(vector));
        break;
      case 10: p |= 0b00000100;
        break;
      case 11: writeAddressH(cpuBus.read(vector + 1));
        break;
      case 12: pc = address;
        break;
      case 13: fetch();
               runningNMI = false;
        break;
    }
  }
  
  // reset
  void reset() {
    jammed = false;
    s = 252;
    
    pc = (cpuBus.read(0xFFFD) << 8) + cpuBus.read(0xFFFC);
    
    fetch(); // store next Opcode
    
    subCycle += 1;
  }
}
