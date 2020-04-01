/* Quick and dirty NES to DMG button driver (originally by Mr.Blinky)
 *
 * Using digital pins so it can be easily run on any Arduino
 * Because DigitalRead and DigitalWrite are pretty slow, no delays are
 * required when changing controller pin states and reading in data
 */

//NES button state masks
#define BS_A      _BV(7)
#define BS_B      _BV(6)
#define BS_SELECT _BV(5)
#define BS_START  _BV(4)
#define BS_RIGHT  _BV(3)
#define BS_LEFT   _BV(2)
#define BS_UP     _BV(1)
#define BS_DOWN   _BV(0)

//DMG button driver pins
#define dout3 7
#define dout2 8
#define dout1 9
#define dout0 10
#define dout 11
#define P10  A0
#define P11  A1
#define P12  A2
#define P13  A3
#define P14   2
#define P15   3

//NES controller pins
#define CONTROLLER_DATA  4
#define CONTROLLER_LATCH 5
#define CONTROLLER_CLOCK 6

volatile uint8_t buttons_state = 0xFF;

void setup()
{
  //Serial.begin(9600);
  //NES controller pins
  pinMode(CONTROLLER_DATA,  INPUT_PULLUP);
  pinMode(CONTROLLER_LATCH, OUTPUT);
  pinMode(CONTROLLER_CLOCK, OUTPUT);

  //DMG button driver pins
  pinMode(P10, OUTPUT);
  pinMode(P11, OUTPUT);
  pinMode(P12, OUTPUT);
  pinMode(P13, OUTPUT);
  pinMode(P14, INPUT_PULLUP);
  pinMode(P15, INPUT_PULLUP);

  attachInterrupt(digitalPinToInterrupt(P14), interruptP14, FALLING);
  attachInterrupt(digitalPinToInterrupt(P15), interruptP15, FALLING);

  DDRB = B10100000;

  /*pinMode(dout3, OUTPUT);
  digitalWrite(dout3, LOW);
  pinMode(dout2, OUTPUT);
  digitalWrite(dout2, LOW);
  pinMode(dout1, OUTPUT);
  digitalWrite(dout1, LOW);
  pinMode(dout0, OUTPUT);
  digitalWrite(dout0, LOW);
  pinMode(dout, OUTPUT);
  digitalWrite(dout, LOW);*/


}

void interruptP14()
{
  PORTF = (buttons_state & 0x0F) << 4;
}

void interruptP15()
{
  PORTF = (buttons_state & 0xF0);
}

void updateButtonState(volatile uint8_t button)
{
  if (digitalRead(CONTROLLER_DATA)) buttons_state |=  button;
  else                              buttons_state &= ~button;
  digitalWrite(CONTROLLER_CLOCK, HIGH); //clock out next button state
  digitalWrite(CONTROLLER_CLOCK, LOW);

}

void loop()
{ //read controller button states
   if(buttons_state != 0xFF) //Slight delay for timing
   {
    delay(50);
   }
    if(buttons_state == 0x5F) //button A -> color pallete mod counter +
  {
    //digitalWrite(dout, HIGH);
    //digitalWrite(dout, LOW);
    delay(50);
    PORTB = B00100000;
    PORTB = B00000000;
  }
  if (buttons_state == 0x9F) //button B -> color pallete mod counter +
  {
    //digitalWrite(dout1, HIGH);
    //digitalWrite(dout1, LOW);
    delay(50);
    PORTB = B10000000;
    PORTB = B00000000;
  }
  
  digitalWrite(CONTROLLER_LATCH, HIGH); //parallel load controller button states
  digitalWrite(CONTROLLER_CLOCK, LOW);  //ensure clock is low when switching to serial mode
  digitalWrite(CONTROLLER_LATCH, LOW);  //switch to serial mode
  
  updateButtonState(BS_A);
  updateButtonState(BS_B);
  updateButtonState(BS_SELECT);
  updateButtonState(BS_START);
  updateButtonState(BS_UP);
  updateButtonState(BS_DOWN);
  updateButtonState(BS_LEFT);
  updateButtonState(BS_RIGHT);

  if (PIND & B00000011) PORTF = 0xF0;
  //Serial.println(buttons_state, BIN);

}
