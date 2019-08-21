String  CFG_PORTA   = "/dev/ttyUSB0";
//String  CFG_PORTA   = "COM6";
boolean CFG_MAXIMAS = true;

import processing.serial.*;

Serial  SERIAL;

PImage IMG;

int ESTADO = 255;  // 0=digitando ESQ, 1=digitando DIR

boolean  END = false;
int      TEMPO_TOTAL;
int      TEMPO_JOGADO;
int      MAXIMA_ESQ;
int      MAXIMA_DIR;
String[] NOMES = new String[2];

float dy; // 0.001 height

float W;
float H;

void setup () {
  serial_liga();
  //delay(50);
  //SERIAL.bufferUntil('\n');
  //SERIAL.clear();
  //SERIAL = new Serial(this, Serial.list()[0], 9600);

  surface.setTitle("FrescoGO! V.1.11");
  size(640, 480);
  //fullScreen();
  IMG = loadImage("data/fresco.png");

  dy = 0.001 * height;

  W = 0.20   * width;
  H = 0.1666 * height;

/*
  if (args != null) {
    CFG_MAXIMAS = args[0].equals("maximas");
  }
*/

  //textFont(createFont("Arial Black", 18));
  textFont(createFont("LiberationSans-Bold.ttf", 18));

  draw_zera();
}

///////////////////////////////////////////////////////////////////////////////
// SERIAL
///////////////////////////////////////////////////////////////////////////////

void serial_liga () {
  SERIAL = new Serial(this, CFG_PORTA, 9600);

  ellipseMode(CENTER);
  fill(0);
  stroke(15, 56, 164);
  ellipse(3.5*W, 5*H, 60*dy, 60*dy);
}

void serial_desliga () {
  SERIAL.stop();
  SERIAL = null;

  ellipseMode(CENTER);
  fill(255,0,0);
  stroke(15, 56, 164);
  ellipse(3.5*W, 5*H, 60*dy, 60*dy);
}

///////////////////////////////////////////////////////////////////////////////
// KEYBOARD
///////////////////////////////////////////////////////////////////////////////

int ctrl (char key) {
  return char(int(key) - int('a') + 1);
}

void ini_nome (float x, int idx) {
  ESTADO = idx;
  NOMES[idx] = "";
  draw_nome(x, NOMES[idx], false);
}

void trata_nome (float x, int idx, String lado) {
  if (key==ENTER || key==RETURN) {
    draw_nome(x, NOMES[idx], true);
    //println(lado + " " + NOMES[idx] + "\n");
    SERIAL.write(lado + " " + NOMES[idx] + "\n");
    delay(100);
    String linha = SERIAL.readStringUntil('\n');
    //println("<<<",linha);
    //assert(linha == "ok");/
    ESTADO = 255;
  } else if (key==BACKSPACE) {
    if (NOMES[idx].length() > 0) {
      NOMES[idx] = NOMES[idx].substring(0, NOMES[idx].length()-1);
    }
    draw_nome(x, NOMES[idx], false);
  } else if (int(key)>=int('a') && int(key)<='z' || int(key)>=int('A') && int(key)<=int('Z') || key=='_'){
    NOMES[idx] = NOMES[idx] + key;
    //println(">>>", key);
    draw_nome(x, NOMES[idx], false);
  }
}

void keyPressed () {
  switch (ESTADO) {
    case 255: // OCIOSO
      if (key == ctrl('e')) {           // CTRL-E
        ini_nome(0,0);
      } else if (key == ctrl('d')) {    // CTRL-D
        ini_nome(3*W,1);
      } else if (key == ctrl('s')) {    // CTRL-S
        if (SERIAL == null) {
          serial_liga();
        } else {
          serial_desliga();
        }
      }
      break;

    case 0: // DIGITANDO ESQ
      trata_nome(0, 0, "esquerda");
      break;
    case 1: // DIGITANDO DIR
      trata_nome(3*W, 1, "direita");
      break;
  }
}

///////////////////////////////////////////////////////////////////////////////
// LOOP
///////////////////////////////////////////////////////////////////////////////

void draw () {
  // realiza operacoes demoradas em um frame separado
  if (END) {
    END = false;
    save();
    draw_tempo(TEMPO_TOTAL-TEMPO_JOGADO, false);
  }

  if (SERIAL==null || SERIAL.available()==0) {
    return;
  }

  String linha = SERIAL.readStringUntil('\n');
  if (linha == null) {
    return;
  }
  //print(">>>",linha);

  String[] campos = split(linha, ";");
  int      codigo = int(campos[0]);

  switch (codigo)
  {
    // RESTART
    case 0: {
      TEMPO_TOTAL  = int(campos[1]);
      TEMPO_JOGADO = 0;
      MAXIMA_ESQ   = 0;
      MAXIMA_DIR   = 0;

      String esq = campos[2];
      String dir = campos[3];
      NOMES[0] = esq;
      NOMES[1] = dir;

      draw_zera();
      draw_tempo(TEMPO_TOTAL, false);
      draw_nome(0,   esq, true);
      draw_nome(3*W, dir, true);
      break;
    }

    // SEQ
    case 1: {
      int tempo  = int(campos[1]);
      int quedas = int(campos[2]);
      String esq = campos[3];
      String dir = campos[4];
      NOMES[0] = esq;
      NOMES[1] = dir;

      TEMPO_JOGADO = tempo;
      draw_tempo(TEMPO_TOTAL-TEMPO_JOGADO, false);

      draw_quedas(quedas);

      draw_nome(0,   esq, true);
      draw_nome(3*W, dir, true);
      break;
    }

    // HIT
    case 2: {
      boolean is_esq     = int(campos[1]) == 0;
      boolean is_back    = int(campos[2]) == 1;
      int     velocidade = int(campos[3]);
      int     pontos     = int(campos[4]);
      boolean is_behind  = (int(campos[5]) == 1) && (TEMPO_JOGADO >= 30);
      int     backs      = int(campos[6]);      // TODO
      int     back_avg   = int(campos[7]);
      int     back_max   = int(campos[8]);
      int     fores      = int(campos[9]);      // TODO
      int     fore_avg   = int(campos[10]);
      int     fore_max   = int(campos[11]);

      color c = (is_back ? color(255,0,0) : color(0,0,255));
      float h = 3*H+10*dy;
      ellipseMode(CENTER);

      if (is_esq)
      {
          draw_pontos(0, pontos, is_behind);
          draw_ultima(0, velocidade);
          //draw_maxima(0, max(back_max,fore_max));
          draw_lado(0,  "Normal", fores, fore_avg);
          draw_lado(W/2,"Revés",  backs, back_avg);

          MAXIMA_ESQ = max(MAXIMA_ESQ, max(back_max,fore_max));
          draw_maxima(2*W, MAXIMA_ESQ);

          // desenha circulo da direita
          fill(c);
          stroke(15, 56, 164);
          ellipse(3*W+80*dy, h, 60*dy, 60*dy);

          // apaga circulo da esquerda
          fill(255);
          stroke(255);
          ellipse(2*W-80*dy, h, 70*dy, 70*dy);
      }
      else
      {
          draw_pontos(4*W, pontos, is_behind);
          draw_ultima(3*W, velocidade);
          //draw_maxima(4*W, max(back_max,fore_max));
          draw_lado(4*W+W/2,"Normal", fores, fore_avg);
          draw_lado(4*W,    "Revés",  backs, back_avg);

          MAXIMA_DIR = max(MAXIMA_DIR, max(back_max,fore_max));
          draw_maxima(2.5*W, MAXIMA_DIR);

          // desenha circulo da esquerda
          fill(c);
          stroke(15, 56, 164);
          ellipse(2*W-80*dy, h, 60*dy, 60*dy);

          // apaga circulo da direita
          fill(255);
          stroke(255);
          ellipse(3*W+80*dy, h, 70*dy, 70*dy);
      }
      break;
    }

    // TICK
    case 3: {
      int tempo  = int(campos[1]);
      int total  = int(campos[2]);
      int golpes = int(campos[3]);
      int media  = int(campos[4]);

      if (tempo >= (TEMPO_JOGADO-TEMPO_JOGADO%5)+5) {
        TEMPO_JOGADO = tempo;
        draw_tempo(TEMPO_TOTAL-TEMPO_JOGADO, false);
      }
      draw_total(total);
      //draw_golpes(golpes);
      if (TEMPO_JOGADO >= 5) {
          draw_media(media);
      }
      break;
    }

    // FALL
    case 4: {
      int quedas = int(campos[1]);
      draw_quedas(quedas);
      draw_ultima(0, 0);
      draw_ultima(3*W, 0);
      break;
    }

    // END
    case 5: {
      END = true; // salva o jogo no frame seguinte
      draw_tempo(TEMPO_TOTAL-TEMPO_JOGADO, true);
      draw_ultima(0, 0);
      draw_ultima(3*W, 0);
    }
  }
}

///////////////////////////////////////////////////////////////////////////////
// DRAW
///////////////////////////////////////////////////////////////////////////////

void draw_zera () {
  draw_logos();
  draw_tempo(0, false);

  draw_quedas(0);
  //draw_golpes(0);

  draw_nome  (0,   "", false);
  draw_nome  (3*W, "", false);

  //draw_maxima(0, 0);
  draw_ultima(0, 0);
  draw_media(0);
  draw_ultima(3*W, 0);
  //draw_maxima(4*W, 0);

  stroke(0);
  fill(255);
  rect(2*W, 3*H, W, H);
  draw_maxima(2.0*W, 0);
  draw_maxima(2.5*W, 0);

  draw_lado(0,      "Normal", 0, 0);
  draw_lado(W/2,    "Revés",  0, 0);
  draw_lado(4*W+W/2,"Normal", 0, 0);
  draw_lado(4*W,    "Revés",  0, 0);

  draw_pontos(0*W, 0, false);
  draw_pontos(4*W, 0, false);
  draw_total(0);
}

void draw_logos () {
  fill(255);
  float w  = W+W/2;
  float x2 = 3*W+W/2;
  rect(0,       0, w, H);
  rect(3*W+W/2, 0, w, H);
  imageMode(CENTER);
  image(IMG, w/2,    H/2);
  image(IMG, x2+w/2, H/2);
}

void draw_tempo (int tempo, boolean ended) {
  String mins = nf(tempo / 60, 2);
  String segs = nf(tempo % 60, 2);

  if (ended) {
    fill(255,0,0);
  } else {
    fill(0);
  }
  rect(W+W/2, 0, 2*W, H);

  fill(255);
  textSize(120*dy);
  textAlign(CENTER, CENTER);
  text(mins+":"+segs, width/2, H/2-10*dy);
}

void draw_nome (float x, String nome, boolean ok) {
  stroke(0);
  fill(255);
  rect(x, H, 2*W, H);
  if (ok) {
    fill(0, 0, 255);
  } else {
    nome = nome + "_";
    fill(255, 0, 0);
  }
  textSize(85*dy);
  textAlign(CENTER, CENTER);
  text(nome, x+W, H+H/2-5*dy);
}

void draw_quedas (int quedas) {
  stroke(0);
  fill(255);
  rect(2*W, H, W, H);

  textAlign(CENTER, TOP);

/*
  fill(0);
  textSize(30*dy);
  text("Quedas", width/2, H+5*dy);
*/

  fill(255, 0, 0);
  ellipseMode(CENTER);
  ellipse(2*W+W/2, H+H/2, 0.9*H, 0.9*H);

  fill(0);
  textSize(90*dy);
  text(quedas, width/2, H+30*dy);
}

void draw_ultima (float x, int ultima) {
  stroke(0);
  fill(255);
  rect(x, 2*H, 2*W, 2*H);

  textAlign(CENTER, CENTER);
  fill(0);

  if (ultima != 0) {
    textSize(160*dy);
    text(ultima, x+W, 3*H-50*dy);
    textSize(40*dy);
    text("km/h", x+W, 3*H+70*dy);
  }
}

void draw_media (int media) {
  stroke(0);
  fill(255);
  rect(2*W, 2*H, W, H);

  textAlign(CENTER, TOP);
  fill(0);

  textAlign(CENTER, CENTER);
  textSize(90*dy);
  if (media != 0) {
    text(media, width/2, 2*H+H/2-25*dy);
  } else {
    text("-", width/2, 2*H+H/2-25*dy);
  }
  textSize(25*dy);
  text("média", width/2, 2*H+H/2+50*dy);
}

void draw_maxima (float x, int maxima) {
  noStroke();
  fill(255);
  rect(x+2, 3*H+2, W/2-4, H-4);

  textAlign(CENTER, TOP);
  fill(0);

  textAlign(CENTER, CENTER);
  textSize(60*dy);
  text(maxima, x+W/4, 3*H+H/2-20*dy);
  textSize(25*dy);
  text("<--    máx    -->", width/2, 3*H+H/2+50*dy);
}

/*
void draw_golpes (int golpes) {
  stroke(0);
  fill(255);
  rect(2*W, 4*H, W, H);

  textAlign(CENTER, CENTER);

  //textSize(25*dy);
  //text("Golpes", width/2, 4*H+5*dy);

  fill(0);
  textSize(90*dy);
  text(golpes, width/2, 4*H+H/2-5*dy);
}
*/

void draw_lado (float x, String lado, int n, int avg) {
  if (!CFG_MAXIMAS) {
    return;
  }

  stroke(0);
  fill(255);
  rect(x, 4*H, W/2, H);

  fill(0);
  textAlign(CENTER, TOP);
  textSize(30*dy);
  text(lado, x+W/4, 4*H+5*dy);

  textAlign(CENTER, CENTER);
  textSize(50*dy);
  text(n,   x+W/4-10*dy, 4*H+H/2+0*dy);
  textSize(25*dy);
  text(avg, x+W/4+40*dy, 4*H+H/2+40*dy);
}

/*
void draw_maxima (float x, int max) {
  stroke(0);
  fill(255);
  rect(x, 4*H, W, H);

  textAlign(CENTER, TOP);
  fill(0);

  textSize(25*dy);
  text("Máxima", x+W/2, 4*H+5*dy);

  //if (max != 0)
  {
    textSize(90*dy);
    text(max, x+W/2, 4*H+36*dy+5*dy);
  }
}
*/

void draw_pontos (float x, int pontos, boolean is_behind) {
  float  h = (CFG_MAXIMAS ? 5*H : 4*H);
  float dh = (CFG_MAXIMAS ? 1*H : 2*H);

  stroke(0);
  if (is_behind) {
      fill(255,0,0);
  } else {
      fill(255);
  }
  rect(x, h, W, dh);
  fill(0);
  textSize(70*dy);
  textAlign(CENTER, CENTER);
  text(pontos, x+W/2, h+dh/2-10*dy);
}

void draw_total (int total) {
  fill(0);
  rect(W, 4*H, 3*W, 2*H);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(200*dy);
  text(total, width/2, 5*H-20*dy);
}

///////////////////////////////////////////////////////////////////////////////
// SAVE
///////////////////////////////////////////////////////////////////////////////

void save () {
  String ts = "" + year() + nf(month(),2) + nf(day(),2) + nf(hour(),2) + nf(minute(),2) + nf(second(),2);
  saveFrame("relatorios/frescogo-"+ts+"-"+NOMES[0]+"-"+NOMES[1]+".png");

  delay(1000);
  SERIAL.write("relatorio\n");
  delay(40000);

  byte[] LOG = new byte[32768];
  LOG = SERIAL.readBytes();
  saveBytes("relatorios/frescogo-"+ts+"-"+NOMES[0]+"-"+NOMES[1]+".txt", LOG);
}
