#include <stdint.h>

#define CORDIC_BASE       0x00001000UL

#define CORDIC_CTRL       (*(volatile uint32_t *)(CORDIC_BASE + 0x00))
#define CIRC_X            (*(volatile int32_t  *)(CORDIC_BASE + 0x04))
#define CIRC_Y            (*(volatile int32_t  *)(CORDIC_BASE + 0x08))
#define CIRC_Z            (*(volatile int32_t  *)(CORDIC_BASE + 0x0C))

#define LIN_X             (*(volatile int32_t  *)(CORDIC_BASE + 0x10))
#define LIN_Y             (*(volatile int32_t  *)(CORDIC_BASE + 0x14))
#define LIN_Z             (*(volatile int32_t  *)(CORDIC_BASE + 0x18))

#define HYP_X             (*(volatile int32_t  *)(CORDIC_BASE + 0x1C))
#define HYP_Y             (*(volatile int32_t  *)(CORDIC_BASE + 0x20))
#define HYP_Z             (*(volatile int32_t  *)(CORDIC_BASE + 0x24))

#define CORDIC_START      (*(volatile uint32_t *)(CORDIC_BASE + 0x28))
#define CORDIC_STATUS     (*(volatile uint32_t *)(CORDIC_BASE + 0x2C))
#define CORDIC_LATENCY    (*(volatile uint32_t *)(CORDIC_BASE + 0x30))

#define CIRC_X_OUT        (*(volatile int32_t  *)(CORDIC_BASE + 0x34))
#define CIRC_Y_OUT        (*(volatile int32_t  *)(CORDIC_BASE + 0x38))
#define CIRC_Z_OUT        (*(volatile int32_t  *)(CORDIC_BASE + 0x3C))

#define LIN_X_OUT         (*(volatile int32_t  *)(CORDIC_BASE + 0x40))
#define LIN_Y_OUT         (*(volatile int32_t  *)(CORDIC_BASE + 0x44))
#define LIN_Z_OUT         (*(volatile int32_t  *)(CORDIC_BASE + 0x48))

#define HYP_X_OUT         (*(volatile int32_t  *)(CORDIC_BASE + 0x4C))
#define HYP_Y_OUT         (*(volatile int32_t  *)(CORDIC_BASE + 0x50))
#define HYP_Z_OUT         (*(volatile int32_t  *)(CORDIC_BASE + 0x54))


/*
 * CTRL WORD
 *
 * [0]     = circular operation
 *           0 = rotation
 *           1 = vectoring
 *
 * [1]     = linear operation
 *           0 = multiply
 *           1 = divide
 *
 * [2]     = hyperbolic operation
 *           0 = rotation
 *           1 = vectoring
 *
 * [7:3]   = circular latency
 * [12:8]  = linear latency
 * [17:13] = hyperbolic latency
 */


/*
 * Example:
 *
 * Circular rotation
 * 16 pipeline stages
 *
 * ctrl =:
 *
 * bit 0       = 0
 * bits 7:3    = 16
 */
#define CTRL_CIRC_ROTATION_16   (16UL << 3)


volatile int32_t result_x;
volatile int32_t result_y;
volatile int32_t result_z;

volatile uint32_t measured_latency;


int main(void)
{
    /*
     * ------------------------------------------------------------
     * CIRCULAR CORDIC TEST
     *
     * Q16.16 format
     *
     * X = 1.0
     * Y = 0.0
     * Z = 0.0 radians
     * ------------------------------------------------------------
     */

    CIRC_X = 0x00010000;   // 1.0
    CIRC_Y = 0x00000000;   // 0.0
    CIRC_Z = 0x00000000;   // 0.0


    /*
     * Select:
     *
     * circular rotation
     * 16 iterations
     */
    CORDIC_CTRL = CTRL_CIRC_ROTATION_16;


    /*
     * Start CORDIC operation.
     */
    CORDIC_START = 1;


    /*
     * Wait until CORDIC becomes idle.
     *
     * STATUS:
     * bit 2 = busy
     * bit 1 = done
     * bit 0 = ready
     */
    while (CORDIC_STATUS & 0x4)
    {
        ;
    }


    /*
     * Read results.
     */
    result_x = CIRC_X_OUT;
    result_y = CIRC_Y_OUT;
    result_z = CIRC_Z_OUT;

    measured_latency = CORDIC_LATENCY;


    /*
     * Keep processor alive.
     */
    while (1)
    {
        ;
    }

    return 0;
}