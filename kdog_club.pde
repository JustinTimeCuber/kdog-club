import java.text.*;

DecimalFormat df0 = new DecimalFormat("0");
DecimalFormat df1 = new DecimalFormat("0.0");
DecimalFormat df2 = new DecimalFormat("0.00");
int game_state = 0;
int level = 1;
int timer = 0;
int score = 0;
int terrain_difficulty = 1;
int[] terrain;
int terrain_offset;
int terrain_array_start_index;
int delta_score = 0;
int total_checkmarks = 0;
int timeout = 3000;
boolean realistic_rotation = false;
boolean q_pressed = false;
boolean e_pressed = false;
boolean sh_pressed = false;
boolean ct_pressed = false;
float dry_mass = 9500; // kg
float fuel = 400; // kg
float initial_fuel = 400; // kg
float mdot_max = 15; // kg/s
float isp = 3200; // m/s
float vx = 50; // m/s
float vy = 0; // m/s
float px = 0; // m
float py = 100; // m
float throttle = 0;
float rotation = 3*PI/4; // rad (ccw from +x)
float rotation_render = 3*PI/4; // rad
float rotation_rate = 0; // rad/s
float landing_score = 0;
float[] engine_issues = {1, 0, 0, 0, 0}; // {fluctuation frequency (Hz), fluctuation amplitude (%), thrust offset (rad), minimum throttle (%), sensor failure (T/F)}
PImage kdogclub;
String checkmarks = "";
void setup() {
  kdogclub = loadImage("kdogclub.png");
  fullScreen();
  frameRate(25);
}
void draw() {
  background(0);
  if(game_state == 0) {
    image(kdogclub, (width - kdogclub.width*height/kdogclub.height)/2, 0, kdogclub.width*height/kdogclub.height, height);
    fill(0);
    stroke(255);
    strokeWeight(2);
    rect(width/2 - height/6, 5*height/6, height/3, height/12);
    textSize(height/18);
    fill(255);
    textAlign(CENTER, CENTER);
    text("Play", width/2, 0.87*height);
  }
  if(game_state == 1) {
    timeout--;
    if(timeout <= 0) {
      game_state = 0;
      level = 1;
      score = 0;
      total_checkmarks = 0;
    }
    String info = "Jane \"K-dog\" Knittig wants to land on the moon, but she needs your help.";
    if(timer >= 25) {
      info += "\n\nLevel: " + level + "\nScore: " + score;
    }
    if(timer >= 50) {
      info += "\n\n---Controls---\nFire engine: Z\nCut engine: X\nThrottle up/down: SHIFT/CTRL\nRotate left/right: Q/E";
    }
    if(timer >= 75) {
      info += "\n\n---Details---\nTerrain difficulty: " + difficultyToString(terrain_difficulty) + "\nRotation mode: " + (realistic_rotation ? "Realistic" : "Easy") + 
      "\nFuel: " + df0.format(fuel) + " kg\nSpeed: " + df0.format(vx) + " m/s";
    }
    if(timer >= 100) {
      fill(0);
      stroke(255);
      strokeWeight(2);
      rect(width/2 - height/6, 5*height/6, height/3, height/12);
      textSize(height/18);
      fill(255);
      textAlign(CENTER, CENTER);
      text("Continue", width/2, 0.87*height);
    }
    textAlign(CENTER, TOP);
    textSize(height/36);
    text(info, width/2, height/8);
    timer++;
  }
  if(game_state == 2) {
    timer++;
    if(!realistic_rotation) {
      rotation_rate = 0;
    }
    if(keyPressed) {
      if(q_pressed) {
        if(realistic_rotation) {
          if(fuel >= 0.0012) {
            rotation_rate += 120/(dry_mass + fuel);
            fuel -= 0.0012;
          }
        } else {
          rotation_rate += 0.5;
        }
      } else if(e_pressed) {
        if(realistic_rotation) {
          if(fuel >= 0.0012) {
            rotation_rate -= 120/(dry_mass + fuel);
            fuel -= 0.0012;
          }
        } else {
          rotation_rate -= 0.5;
        }
      }
      if(sh_pressed) {
        throttle = throttle >= 0.98 ? 1 : max(throttle + 0.02, engine_issues[3]);
      }
      if(ct_pressed) {
        throttle = throttle <= 0.02 + engine_issues[3] ? engine_issues[3] : throttle - 0.02;
      }
    }
    if(!q_pressed && !e_pressed) {
      if(realistic_rotation) {
        if(fuel >= 0.0012) {
          if(rotation_rate > 0) {
            rotation_rate -= 120/(dry_mass + fuel); 
            fuel -= 0.0012;
            if(rotation_rate < 0) {
              fuel -= 0.0012*rotation_rate*(dry_mass + fuel + 0.0012)/120;
              rotation_rate = 0;
            }
          }
          if(rotation_rate < 0) {
            rotation_rate += 120/(dry_mass + fuel); 
            fuel -= 0.0012;
            if(rotation_rate > 0) {
              fuel += 0.0012*rotation_rate*(dry_mass + fuel + 0.0012)/120;
              rotation_rate = 0;
            }
          }
        }
      }
    }
    if(throttle != 0) {
      float dm = (1 + engine_issues[1]*sin(engine_issues[0]*timer*2*PI/25))*mdot_max*throttle/25;
      fuel -= dm;
      if(fuel <= 0) {
        fuel = 0;
        throttle = 0;
      } else {
        float dv = dm*isp/(dry_mass + fuel);
        vx += dv*cos(rotation + engine_issues[2]);
        vy += dv*sin(rotation + engine_issues[2]);
      }
    }
    vy -= 4.905e12*pow(1737000 + py, -2)/25;
    rotation += rotation_rate/25;
    if(rotation > PI) {
      rotation -= 2*PI;
    }
    if(rotation <= -PI) {
      rotation += 2*PI;
    }
    rotateVelocity(vx/(25*(1737000 + py)));
    px += vx/25;
    py += vy/25;
    updateTerrain((int)px - terrain_offset - terrain.length/2);
    rotation_render = rotation;
    if(checkContact()) {
      game_state = 3;
      throttle = 0;
      timer = 0;
    }
    drawTerrain();
    drawLander();
    showStatus();
  }
  if(game_state == 3) {
    timer++;
    drawTerrain();
    drawLander();
    showStatus();
    String text = "";
    if(timer >= 25) {
      if(landing_score < 1) {
        text += "You lovingly landed K-dog on the moon!";
      } else if(landing_score < 2) {
        text += "Uh oh! Be careful, that was a hard landing.";
      } else {
        text += "NoOOoo! You crashed K-dog's spaceship! Game over.";
      }
    }
    if(timer >= 50) {
      text += "\nScore: " + delta_score;
      if(checkmarks.length() > 0 ) {
        text += " (" + checkmarks + ")";
      }
    }
    if(timer >= 150) {
      if(landing_score < 2) {
        level++;
        timer = 0;
        game_state = 1;
        levelSettings(level);
      } else {
        game_state = 4;
        timer = 0;
      }
      return;
    }
    textAlign(CENTER, TOP);
    colorMode(HSB, 50, 1, 1);
    fill(timer % 50, 1, 1);
    text(text, width/2, height/4 + 5);
    colorMode(RGB, 255);
  }
  if(game_state == 4) {
    timer++;
    timeout--;
    if(timeout <= 0) {
      game_state = 0;
      level = 1;
      score = 0;
      total_checkmarks = 0;
    }
    textSize(height/18);
    textAlign(CENTER, CENTER);
    colorMode(HSB, 50, 1, 1);
    fill(timer % 50, 1, 1);
    text("Game Over\nLevel reached: " + level + "\nYour score: " + score + "\nCheckmarks: ✓ x" + total_checkmarks, width/2, height/3);
    colorMode(RGB, 255);
    fill(0);
    stroke(255);
    strokeWeight(2);
    rect(width/2 - height/6, 5*height/6, height/3, height/12);
    fill(255);
    text("Return", width/2, 0.87*height);
  }
}
void levelSettings(int l) {
  timeout = 3000;
  if(l <= 3) {
    terrain_difficulty = 1;
  } else if(l <= 8) {
    terrain_difficulty = 2;
  } else {
    terrain_difficulty = 3;
  }
  realistic_rotation = l >= 5;
  engine_issues = new float[]{1, 0, 0, 0, 0};
  if(l > 8) {
    if(random(3*l) < l - 8) {
      engine_issues[0] = exp(random(-2, 2));
      engine_issues[1] = random(0.2);
    }
    if(random(3*l) < l - 8) {
      engine_issues[2] = random(-0.1, 0.1);
    }
    if(random(3*l) < l - 8) {
      engine_issues[3] = random(0.5, 0.94);
    }
    if(random(3*l) < l - 8) {
      engine_issues[4] = 1;
    }
  }
  if(l > 6) {
    l = 6;
  }
  fuel = 100*(2 + l);
  initial_fuel = fuel;
  vx = 20 + 30*l;
  vy = 0;
  px = 0;
  py = 100;
  rotation = map(l, 1, 6, 3*PI/4, 7*PI/8);
  generateTerrain(500);
}
String difficultyToString(int d) {
  if(d == 1) {
    return "Easy";
  }
  if(d == 2) {
    return "Medium";
  }
  return "Hard";
}
boolean mouseInRect(float x1, float y1, float dx, float dy) {
  return mouseX > x1 && mouseX < x1 + dx && mouseY > y1 && mouseY < y1 + dy;
}
void generateTerrain(int n) {
  terrain_offset = -n/2;
  terrain = new int[n];
  terrain[terrainIndex(0)] = (int)random(0, 10*terrain_difficulty);
  for(int i = 1; i < terrain.length; i++) {
    float r = random(1);
    if((terrain_difficulty == 1 && r < 0.1) || (terrain_difficulty == 2 && r < 0.15) || (terrain_difficulty == 3 && r < 0.2)) {
      terrain[terrainIndex(i)] = (int)random(0, 10*terrain_difficulty);
    }
    else {
      terrain[terrainIndex(i)] = terrain[terrainIndex(i-1)];
    }
  }
}
void updateTerrain(int n) {
  if(n == 0) {
    return;
  }
  if(n >= terrain.length) {
    updateTerrain(terrain.length - 1);
    updateTerrain(n - terrain.length + 1);
  }
  if(n <= -terrain.length) {
    updateTerrain(1 - terrain.length);
    updateTerrain(terrain.length - n - 1);
  }
  terrain_offset += n;
  if(n > 0) {
    for(int i = 0; i < n; i++) {
      float r = random(1);
      if((terrain_difficulty == 1 && r < 0.1) || (terrain_difficulty == 2 && r < 0.15) || (terrain_difficulty == 3 && r < 0.2)) {
        terrain[terrainIndex(i)] = (int)random(0, 10*terrain_difficulty);
      }
      else {
        terrain[terrainIndex(i)] = terrain[terrainIndex(i - 1)];
      }
    }
    terrain_array_start_index += n;
    while(terrain_array_start_index >= terrain.length) {
      terrain_array_start_index -= terrain.length;
    }
  }
  if(n < 0) {
    n *= -1;
    for(int i = 0; i < n; i++) {
      float r = random(1);
      if((terrain_difficulty == 1 && r < 0.1) || (terrain_difficulty == 2 && r < 0.15) || (terrain_difficulty == 3 && r < 0.2)) {
        terrain[terrainIndex(-1-i)] = (int)random(0, 10*terrain_difficulty);
      }
      else {
        terrain[terrainIndex(-1-i)] = terrain[terrainIndex(-i)];
      }
    }
    terrain_array_start_index -= n;
    while(terrain_array_start_index < 0) {
      terrain_array_start_index += terrain.length;
    }
  }
}
int terrainIndex(int index) {
  index += terrain_array_start_index;
  index %= terrain.length;
  if(index < 0) {
    index += terrain.length;
  }
  return index;
}
void drawTerrain() {
  strokeWeight(2);
  stroke(127);
  for(int i = 0; i < terrain.length - 1; i++) {
    line(trX(i + terrain_offset), trY(terrain[terrainIndex(i)]), trX(i + terrain_offset + 1), trY(terrain[terrainIndex(i + 1)]));
  }
}
void drawLander() {
  noFill();
  stroke(255);
  strokeWeight(2);
  float csr = cos(rotation_render);
  float sir = sin(rotation_render);
  float thrustFactor = 1 + engine_issues[1]*sin(engine_issues[0]*timer*2*PI/25);
  quad(trX(px - 2*csr - 2*sir), trY(py + 2*csr - 2*sir),
       trX(px - 2*csr + 2*sir), trY(py - 2*csr - 2*sir),
       trX(px + 2.25*csr + 1.5*sir), trY(py - 1.5*csr + 2.25*sir),
       trX(px + 2.25*csr - 1.5*sir), trY(py + 1.5*csr + 2.25*sir));
  line(trX(px - 2*csr - 2*sir), trY(py + 2*csr - 2*sir),
       trX(px - 3*csr - 3*sir), trY(py + 3*csr - 3*sir));
  line(trX(px - 2*csr + 2*sir), trY(py - 2*csr - 2*sir),
       trX(px - 3*csr + 3*sir), trY(py - 3*csr - 3*sir));
  fill(255, 127 + 64*throttle*thrustFactor, 0);
  noStroke();
  if(throttle > 0) {
    triangle(trX(px - 2*csr - 0.75*sir), trY(py + 0.75*csr - 2*sir),
             trX(px - 2*csr + 0.75*sir), trY(py - 0.75*csr - 2*sir),
             trX(px - (4 + 4*throttle*thrustFactor)*csr), trY(py - (4 + 4*throttle*thrustFactor)*sir));
  }
}
float getTerrainAt(float x) {
  return map(x, floor(x), floor(x) + 1, terrain[terrainIndex(floor(x) - terrain_offset)], terrain[terrainIndex(floor(x) - terrain_offset + 1)]);
}
boolean checkContact() {
  float csr = cos(rotation);
  float sir = sin(rotation);
  float[] x_points = {px - 2*csr - 2*sir, px - 2*csr + 2*sir,
                      px - 2*csr - sir, px - 2*csr + sir, px - 2*csr,
                      px + 2.25*csr + 1.5*sir, px + 2.25*csr - 1.5*sir,
                      px - 3*csr - 3*sir, px - 3*csr + 3*sir, px};
  float[] y_points = {py + 2*csr - 2*sir, py - 2*csr - 2*sir,
                      py + csr - 2*sir, py - csr - 2*sir, py - 2*sir,
                      py - 1.5*csr + 2.25*sir, py + 1.5*csr + 2.25*sir,
                      py + 3*csr - 3*sir, py - 3*csr - 3*sir, py};
  for(int i = 0; i < 10; i++) {
    float terr = getTerrainAt(x_points[i]);
    if(y_points[i] <= terr) {
      landing_score = 8*abs(rotation/PI - 0.5) + (vy >= -1 ? 0 : -0.25*(vy + 1)) + abs(vx)/2;
      float leg1 = getTerrainAt(px - 3);
      float leg2 = getTerrainAt(px + 3);
      if(abs(leg2 - leg1) < 0.5 && (i == 7 || i == 8) && landing_score < 2) {
        py = (leg1 + leg2)/2 + 3;
        rotation_render = asin((leg2 - leg1)/6) + PI/2;
      } else {
        boolean flat = true;
        float left = getTerrainAt(px - 2);
        for(int j = -1; j <= 2; j++) {
          if(getTerrainAt(px + j) != left) {
            flat = false;
          }
        }
        if(flat && landing_score < 1) {
          landing_score++;
          py = left + 2;
          rotation_render = PI/2;
        } else {
          landing_score += 2;
        }
      }
      delta_score = landing_score >= 2 ? 0 : round(100*(2 - landing_score) + (landing_score < 1 ? 200 : 0) + 100*level + fuel);
      score += delta_score;
      float chm = delta_score + random(-250, 250);
      checkmarks = "";
      for(int j = 0; j < chm; j += 500) {
        checkmarks += "✓";
        total_checkmarks++;
      }
      return true;
    }
  }
  return false;
}
void showStatus() {
  float thrustFactor = 1 + engine_issues[1]*sin(engine_issues[0]*timer*2*PI/25);
  textSize(height/36);
  fill(255);
  textAlign(LEFT, TOP);
  text("Engine status------", 5, 5);
  if(engine_issues[4] != 0) {
    text("Status: Off-nominal", 5, 5 + height/24);
    text("-> Sensor failure", 5, 5 + height/12);
  } else {
    if(engine_issues[1] == 0 && engine_issues[2] == 0 && engine_issues[3] == 0) {
      text("Status: Nominal", 5, 5 + height/24);
    } else {
      text("Status: Off-nominal", 5, 5 + height/24);
      int c = 2;
      if(engine_issues[1] != 0) {
        text("-> Thrust fluctuations", 5, 5 + c*height/24);
        c++;
      }
      if(engine_issues[2] != 0) {
        text("-> Gimbal alignment offset", 5, 5 + c*height/24);
        c++;
      }
      if(engine_issues[3] != 0) {
        text("-> Bad throttle valve", 5, 5 + c*height/24);
        c++;
      }
    }
  }
  textAlign(RIGHT, TOP);
  text("------GNC data", width - 5, 5);
  text("Horizontal velocity: " + df1.format(vx) + " m/s", width - 5, height/24 + 5);
  if(abs(vy) < 10) {
    text("Vertical velocity: " + df2.format(vy) + " m/s", width - 5, height/12 + 5);
  } else {
    text("Vertical velocity: " + df1.format(vy) + " m/s", width - 5, height/12 + 5);
  }
  text("Altitude: " + df0.format(py) + " m", width - 5, height/8 + 5);
  text("Orientation: " + df0.format(rotation*180/PI) + "°", width - 5, height/6 + 5); // replace deg with degree symbol
  if(realistic_rotation) {
    text("Rotation rate: " + df1.format(rotation_rate*180/PI) + "°/s", width - 5, 5*height/24 + 5); // replace deg with degree symbol
  }
  if(engine_issues[4] == 0) {
    noStroke();
    fill(0, 127, 0);
    if(fuel < 100) {
      fill(127, 127, 0);
    }
    if(fuel < 60) {
      fill(127, 6.35 * (fuel - 40), 0);
    }
    if(fuel < 40) {
      fill(127, 0, 0);
    }
    rect(width/6, height*9/10, width/4*fuel/initial_fuel, height/15);
    fill(0, 0, 100 + thrustFactor*throttle*60);
    rect(width*7/12, height*9/10, width/4*min(thrustFactor*throttle, 1), height/15);
    strokeWeight(2);
    stroke(255);
    noFill();
    rect(width/6, height*9/10, width/4, height/15);
    rect(width*7/12, height*9/10, width/4, height/15);
    fill(255);
    textAlign(CENTER, CENTER);
    text("Fuel remaining: " + df1.format(fuel) + " kg", width*7/24, height*14/15);
    text("Thrust: " + df1.format(thrustFactor*throttle*mdot_max*isp/1000) + " kN (" + df0.format(100*thrustFactor*throttle) + "%)", width*17/24, height*14/15);
  }
}
void rotateVelocity(float theta) {
  float vx_n = vx*cos(theta) - vy*sin(theta);
  float vy_n = vy*cos(theta) + vx*sin(theta);
  vx = vx_n;
  vy = vy_n;
}
float trX(float x) {
  if(py < 40 && abs(vx) < 5) {
    return map(x - px, 0, 50, width/2, width/2 + 2*height/3);
  }
  return map(x - px, 0, 100, width/2, width/2 + 2*height/3);
}
float trY(float y) {
  if(py < 40 && abs(vx) < 5) {
    return map(y, 0, 50, 5*height/6, height/6);
  }
  return map(y, 0, 100, 5*height/6, height/6);
}
float sz(float s) {
  if(py < 40 && abs(vx) < 5) {
    return map(s, 0, 50, 0, 2*height/3);
  }
  return map(s, 0, 100, 0, 2*height/3);
}
void mousePressed() {
  timeout = 3000;
  if(game_state == 0) {
    if(mouseInRect(width/2 - height/6, 5*height/6, height/3, height/12)) {
      timer = 0;
      game_state = 1;
      levelSettings(level);
    }
  } else if(game_state == 1) {
    if(mouseInRect(width/2 - height/6, 5*height/6, height/3, height/12) && timer >= 100) {
      timer = 0;
      game_state = 2;
    }
  } else if(game_state == 4) {
    if(mouseInRect(width/2 - height/6, 5*height/6, height/3, height/12)) {
      game_state = 0;
      level = 1;
      score = 0;
      total_checkmarks = 0;
    }
  }
}
void keyPressed() {
  timeout = 3000;
  if(key == 'q' || key == 'Q') {
    q_pressed = true;
  }
  if(key == 'e' || key == 'E') {
    e_pressed = true;
  }
  if((key == 'z' || key == 'Z') && game_state == 2 && fuel > 0) {
    throttle = 1;
  }
  if((key == 'x' || key == 'X') && game_state == 2) {
    throttle = 0;
  }
  if(key == CODED && keyCode == SHIFT && game_state == 2 && fuel > 0) {
    sh_pressed = true;
  }
  if(key == CODED && keyCode == CONTROL && game_state == 2 && fuel > 0) {
    ct_pressed = true;
  }
}
void keyReleased() {
  q_pressed = false;
  e_pressed = false;
  sh_pressed = false;
  ct_pressed = false;
}
void mouseMoved() {
  timeout = 3000;
}
