PGraphics ntscFilter(PGraphics gfx) {
  PGraphics buffer = createGraphics(256, 240);
  buffer.beginDraw();
  buffer.image(gfx, -1, 0, gfx.width, gfx.height);
  
  buffer.loadPixels();
  
  for (int pInd = 0; pInd < buffer.pixels.length; pInd += 1) {
    int[] indexes = new int[0];
    
    int x = pInd % buffer.width;
    int y = (int)Math.floor(pInd / buffer.width) * buffer.width;
    int xy = (int)Math.floor(pInd / buffer.width);
    
    int pOffset = 1;
    int nOffset = -1;

    indexes = append(indexes,
      mathClamp(
        mathClamp(
          x + pOffset,
          0, 
          buffer.width - 1
        ),
        0,
        buffer.pixels.length - 1
      )
    );
    indexes = append(indexes,
      mathClamp(
        mathClamp(
          x + nOffset,
          0, 
          buffer.width - 1
        ),
        0,
        buffer.pixels.length - 1
      )
    );
    
    float true0 = red(buffer.pixels[pInd]);
    float true1 = green(buffer.pixels[pInd]);
    float true2 = blue(buffer.pixels[pInd]);
    
    switch ((pInd + y) % 3) {
      case 2:
        for (int index = 0; index < indexes.length; index ++) { // true0
          true0 = (true0 + red(buffer.pixels[indexes[index] + y])) / 2;
        }
        true0 += red(buffer.pixels[pInd]);
        true0 /= 2;
        buffer.pixels[pInd] = color(true0, green(buffer.pixels[pInd]), blue(buffer.pixels[pInd]));
        
        for (int index = 0; index < indexes.length; index ++) { // true1
          true1 = (true1 + green(buffer.pixels[indexes[index] + y])) / 2;
        }
        true1 += green(buffer.pixels[pInd]);
        true1 /= 2;
        buffer.pixels[pInd] = color(red(buffer.pixels[pInd]), true1, blue(buffer.pixels[pInd]));
        break;
      case 1:
        for (int index = 0; index < indexes.length; index ++) { // true0
          true0 = (true0 + red(buffer.pixels[indexes[index] + y])) / 2;
        }
        true0 += red(buffer.pixels[pInd]);
        true0 /= 2;
        buffer.pixels[pInd] = color(true0, green(buffer.pixels[pInd]), blue(buffer.pixels[pInd]));
        
        for (int index = 0; index < indexes.length; index ++) { // true1
          true2 = (true2 + blue(buffer.pixels[indexes[index] + y])) / 2;
        }
        true2 += blue(buffer.pixels[pInd]);
        true2 /= 2;
        buffer.pixels[pInd] = color(red(buffer.pixels[pInd]), green(buffer.pixels[pInd]), true2);
      case 0:
        for (int index = 0; index < indexes.length; index ++) { // true1
          true1 = (true1 + green(buffer.pixels[indexes[index] + y])) / 2;
        }
        true1 += green(buffer.pixels[pInd]);
        true1 /= 2;
        buffer.pixels[pInd] = color(red(buffer.pixels[pInd]), true1, blue(buffer.pixels[pInd]));
        
        for (int index = 0; index < indexes.length; index ++) { // true1
          true2 = (true2 + blue(buffer.pixels[indexes[index] + y])) / 2;
        }
        true2 += blue(buffer.pixels[pInd]);
        true2 /= 2;
        buffer.pixels[pInd] = color(red(buffer.pixels[pInd]), green(buffer.pixels[pInd]), true2);
        break;
    }
  }
  
  buffer.updatePixels();
  
  return buffer;
}
