//This example was taken from this video:
//https://www.youtube.com/watch?v=ENGGh0ajE2M
//It's a very good way to start calibrating
//Used a PWM encoder for this version
//It's possible using a SPI encoder will give better results

#include <SimpleFOC.h>
#include <Arduino.h>
#include <SPI.h>

#define PIN_CS    5 
#define PIN_SCK   36
#define PIN_MOSI  35
#define PIN_MISO  37


// BLDC motor & driver instance
BLDCMotor motor = BLDCMotor(11);
// Driver pins: PWM1A, PWM1B, PWM1C, enable pin
BLDCDriver3PWM driver = BLDCDriver3PWM(1, 3, 7, 10);

// Magnetic sensor instance - just for monitoring
MagneticSensorSPI sensor = MagneticSensorSPI(5, 14, 0x3FFF);

float target = 0.0f;

void serialLoop() {
  static String received_chars;

  while (Serial.available()) {
    char inChar = (char) Serial.read();
    received_chars += inChar;
    if (inChar == '\n') {
      target = received_chars.toFloat();
      Serial.print("Target = "); Serial.println(target);
      received_chars = "";
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(100);

  uint32_t t0 = millis();
  while (!Serial && (millis() - t0 < 3000)) delay(10);

  Serial.println("+----------------------------------------------------------+");
  Serial.println("|                      FW INFORMATION                      |");
  Serial.println("+----------------------------------------------------------+");
  Serial.printf ("| SHA: %-12s%-8s | Built: %s %s   |\n",
                FW_GIT_HASH,
                FW_GIT_DIRTY,
                __DATE__,
                __TIME__);
  Serial.println("+----------------------------------------------------------+");

  //sensor.spi_mode = SPI_MODE0;
  //sensor.clock_speed =  500000;
  SPI.begin(PIN_SCK, PIN_MISO, PIN_MOSI, PIN_CS);
  sensor.init();
  motor.linkSensor(&sensor);

  motor.PID_velocity.P = 0.15; // pwm sensor 0.04;
  motor.PID_velocity.I = 0.3; // pwm sensor 0.5 or 0.2
  motor.PID_velocity.D = 0.0;
  //motor.PID_velocity.output_ramp = 1000;
  motor.LPF_velocity.Tf = 0.01;

  //Zmotor.P_angle.P = 1;

  driver.voltage_power_supply = 12;
  driver.voltage_limit = 5;
  driver.init();
  motor.linkDriver(&driver);

  motor.voltage_limit = 6; // [V]
  motor.velocity_limit = 20; //[rad/s]
  motor.voltage_sensor_align = 1;

  //open loop
  motor.phase_resistance = 6.34; // per datasheet in Ohms
  //motor.torque_controller = TorqueControlType::voltage;
  motor.controller = MotionControlType::velocity;

  motor.useMonitoring(Serial);

  motor.init();
  motor.initFOC();
  Serial.println(motor.zero_electric_angle);
}

void loop () {

  serialLoop();
  //motor.PID_velocity.I = target;

  //sensor.update();
  motor.loopFOC();
  motor.move(target);
  motor.monitor();
  //delay(1);
}
