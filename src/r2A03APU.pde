RicohAPU apu;

class RicohAPU {
  float SPEED = 2; // stuff for granularity sake
  float apuCycles = 0;
  
  float[] DUTY_CYCLE = {0.125, 0.25, 0.5, 0.75};
  int[] LENGTH_COUNTER = {
    10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14,   // $00 - $0F
    12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30 // $10 - $1F
  };
  float CLOCK = 1789773;
  float MAX = 0.05; // not to hurt ears
  
  int mode = 1;
  
  int seqStep = 0;
  
  Pulse pulse1;
  Pulse pulse2;
  TriOsc triangle;
  
  // frame interrupt
  boolean interruptInhibit = false;
  
  // pulse 1 registers
  int pulse1Duty = 0;
  boolean pulse1Loop = false;
  boolean pulse1ConstantVolume = false;
  int pulse1Volume = 0;
  int pulse1Timer = 0;
  int pulse1Counter = 0;
  boolean pulse1SweepEnabled = false;
  boolean pulse1SweepNegate = false;
  int pulse1Sweep = 0;
  
  // pulse 2 registers
  int pulse2Duty = 0;
  boolean pulse2Loop = false;
  boolean pulse2ConstantVolume = false;
  int pulse2Volume = 0;
  int pulse2Timer = 0;
  int pulse2Counter = 0;
  boolean pulse2SweepEnabled = false;
  boolean pulse2SweepNegate = false;
  int pulse2Sweep = 0;
  
  // triangle registers
  boolean triangleControl = false;
  int triangleLinearCounter = 0;
  int triangleTimer = 0;
  int triangleCounter = 0;
  
  void clock() {
    switch(mode) {
      case 0: // 4-step sequence
        seqStep %= 4;
        switch(seqStep) {
          case 0:
          case 2:
            clockTriangleCounter();
            break;
          
          case 1:
          case 3:
            clockTriangleCounter();
          
            // freq
            pulse1.freq(CLOCK / (16 * pulse1Timer + 1));
            pulse2.freq(CLOCK / (16 * pulse2Timer + 1));
            triangle.freq(CLOCK / (16 * triangleTimer + 1));
            
            if (pulse1SweepEnabled) {
              pulse1Timer = pulse1SweepNegate ? mathClamp(pulse1Timer - (pulse1Timer >> pulse1Sweep), 0, 0x7FF)
              : mathClamp(pulse1Timer + (pulse1Timer >> pulse1Sweep), 0, 0x7FF);
            }
            
            if (pulse2SweepEnabled) {
              pulse2Timer = pulse2SweepNegate ? mathClamp(pulse2Timer - (pulse2Timer >> pulse2Sweep), 0, 0x7FF)
              : mathClamp(pulse2Timer + (pulse2Timer >> pulse2Sweep), 0, 0x7FF);
            }
            
            clockLengthCounter();
            interruptInhibit = true;
            break;
        }
        break;
        
      case 1: // 5-step sequence
        seqStep %= 5;
        switch(seqStep) {
          case 0:
          case 2:
            clockTriangleCounter();
            break;
          
          case 1:
          case 4:
            clockTriangleCounter();
            
            // freq
            pulse1.freq(CLOCK / (16 * pulse1Timer + 1));
            pulse2.freq(CLOCK / (16 * pulse2Timer + 1));
            triangle.freq(CLOCK / (16 * triangleTimer + 1));
            
            if (pulse1SweepEnabled) {
              pulse1Timer = pulse1SweepNegate ? mathClamp(pulse1Timer - (pulse1Timer >> pulse1Sweep), 0, 0x7FF)
              : mathClamp(pulse1Timer + (pulse1Timer >> pulse1Sweep), 0, 0x7FF);
            }
            
            if (pulse2SweepEnabled) {
              pulse2Timer = pulse2SweepNegate ? mathClamp(pulse2Timer - (pulse2Timer >> pulse2Sweep), 0, 0x7FF)
              : mathClamp(pulse2Timer + (pulse2Timer >> pulse2Sweep), 0, 0x7FF);
            }
            
            clockLengthCounter();
            break;
        }
        break;
    }
    
    seqStep += 1;
  }
  
  void clockTriangleCounter() {
    if (triangleLinearCounter > 0) {
      triangle.amp(MAX / 2);
      
      if (!triangleControl) triangleLinearCounter -= 1;
    } else {
      triangle.amp(0);
    }
  }
  
  void clockLengthCounter() {
    // length counter + other
    // pulse1
    if (pulse1Counter > 0 && pulse1Timer >= 8) {
      pulse1.amp((float)(pulse1Volume) / 15 * MAX);
      
      if (!pulse1ConstantVolume) pulse1Volume = pulse1Loop ? (pulse1Volume - 1) & 0xF : mathClamp(pulse1Volume - 1, 0, 15);
      
      if (!pulse1Loop) pulse1Counter -= 1;
    } else {
      pulse1.amp(0);
    }
    
    // pulse2
    if (pulse2Counter > 0 && pulse2Timer >= 8) {
      pulse2.amp((float)(pulse2Volume) / 15 * MAX);
      
      if (!pulse2ConstantVolume) pulse2Volume = pulse2Loop ? (pulse2Volume - 1) & 0xF : mathClamp(pulse2Volume - 1, 0, 15);
      
      if (!pulse2Loop) pulse2Counter -= 1;
    } else {
      pulse2.amp(0);
    }
    
    // triangle
    if (triangleCounter > 0) {
      if (triangleLinearCounter > 0) {
        triangle.amp(MAX / 2);
      } else {
        triangle.amp(0);
      }
      
      if (!triangleControl) triangleCounter -= 1;
    } else {
      triangle.amp(0);
    }
  }
}
