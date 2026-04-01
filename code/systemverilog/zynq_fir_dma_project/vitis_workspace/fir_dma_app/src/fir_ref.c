#include "fir_ref.h"

void fir8_reference(const int16_t *in, int16_t *out, int n)
{
    int16_t h[8] = {-8,0,40,96,96,40,0,-8};

    for(int i=0;i<n;i++){
        int32_t acc=0;
        for(int k=0;k<8;k++){
            int idx=i-k;
            int16_t x = (idx>=0)?in[idx]:0;
            acc += x*h[k];
        }
        out[i]=acc>>8;
    }
}