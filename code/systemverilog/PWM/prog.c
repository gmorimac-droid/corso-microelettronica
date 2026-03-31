#include <stdint.h>

#define PWM_BASE_ADDR  0x43C00000U

#define REG32(addr)    (*(volatile uint32_t *)(addr))

#define PWM_CONTROL_ADDR   (PWM_BASE_ADDR + 0x00U)
#define PWM_PERIOD_ADDR    (PWM_BASE_ADDR + 0x04U)
#define PWM_DUTY_ADDR      (PWM_BASE_ADDR + 0x08U)
#define PWM_STATUS_ADDR    (PWM_BASE_ADDR + 0x0CU)

static void delay(volatile uint32_t count)
{
    while (count--) {
        ;
    }
}

static void pwm_disable(void)
{
    REG32(PWM_CONTROL_ADDR) = 0x0U;
}

static void pwm_enable(void)
{
    REG32(PWM_CONTROL_ADDR) = 0x1U;
}

static void pwm_set_period(uint32_t period)
{
    REG32(PWM_PERIOD_ADDR) = period;
}

static void pwm_set_duty(uint32_t duty)
{
    REG32(PWM_DUTY_ADDR) = duty;
}

static uint32_t pwm_get_status(void)
{
    return REG32(PWM_STATUS_ADDR);
}

int main(void)
{
    pwm_disable();

    pwm_set_period(1000U);
    pwm_set_duty(500U);

    pwm_enable();

    while (1) {
        pwm_set_duty(100U);   // 10%
        delay(4000000);

        pwm_set_duty(250U);   // 25%
        delay(4000000);

        pwm_set_duty(500U);   // 50%
        delay(4000000);

        pwm_set_duty(750U);   // 75%
        delay(4000000);

        pwm_set_duty(900U);   // 90%
        delay(4000000);

        (void)pwm_get_status();
    }

    return 0;
}