#include "types.h"
#include "cnn.h"

int32_t times(int32_t a, int32_t b) {
  int32_t a_neg = a < 0;
  int32_t b_neg = b < 0;
  int32_t result = 0;
  if (a_neg) a = -a;
  if (b_neg) b = -b;
  while (b) {
    if (b & 1) {
      result += a;
    }
    a <<= 1;
    b >>= 1;
  }
  if ((a_neg && !b_neg) || (!a_neg && b_neg)) {
    result = -result;
  }
  return result;
}

int32_t cast_si32(int8_t input) {
  int32_t val = input;
  return (input > 127) ? (val - 256) : val;
}

// Convolution 3D
void conv3D_sw_1(int8_t *ifm, int8_t *wt, int32_t *ofm) {

  int f, d, i, j, m, n;
  int ofm_idx, ifm_idx, wt_idx;

  int ofm_offset = 0;
  int ifm_offset = 0;
  int wt_offset  = 0;

  for (f = 0; f < CV1_DEPTH; ++f) {

    ofm_idx = 0;
    for (i = 0; i < CV1_DIM; ++i) {
      for (j = 0; j < CV1_DIM; ++j) {
        ofm[ofm_offset + ofm_idx] = 0;
        ofm_idx += 1;
      }
    }

    ifm_offset = 0;
    for (d = 0; d < IMG_DEPTH; ++d) {

      ofm_idx = 0;
      int ifm_idx0 = 0;

      for (i = 0; i < CV1_DIM; ++i) {
        for (j = 0; j < CV1_DIM; ++j) {
          wt_idx = 0;

          int32_t tmp = 0;
          int ifm_idx1 = 0;

          for (m = 0; m < WT1_DIM; ++m) {
            for (n = 0; n < WT1_DIM; ++n) {
              int32_t ifm_value = cast_si32(ifm[ifm_offset + ifm_idx0 + ifm_idx1]);
              int32_t wt_value  = cast_si32(wt[wt_offset + wt_idx]);
              int32_t prod = times(ifm_value, wt_value);
              tmp += prod;

              ifm_idx1 += 1;
              wt_idx   += 1;
            } // n

            ifm_idx1 += IMG_DIM - WT1_DIM;
          } // m

          ofm[ofm_offset + ofm_idx] += tmp;

          ofm_idx  += 1;
          ifm_idx0 += 1;
        } // j

        ifm_idx0 += IMG_DIM - CV1_DIM;
      } // i

      ifm_offset += IMG_SIZE;
      wt_offset  += WT1_SIZE;
    } // d

    ofm_offset += CV1_SIZE;
  } // f
}

void conv3D_sw_2(int8_t *ifm, int8_t *wt, int32_t *ofm) {

  int f, d, i, j, m, n;
  int ofm_idx, ifm_idx, wt_idx;

  int ofm_offset = 0;
  int ifm_offset = 0;
  int wt_offset  = 0;

  for (f = 0; f < CV2_DEPTH; ++f) {

    ofm_idx = 0;
    for (i = 0; i < CV2_DIM; ++i) {
      for (j = 0; j < CV2_DIM; ++j) {
        ofm[ofm_offset + ofm_idx] = 0;
        ofm_idx += 1;
      }
    }

    ifm_offset = 0;
    for (d = 0; d < P1_DEPTH; ++d) {

      ofm_idx = 0;
      int ifm_idx0 = 0;

      for (i = 0; i < CV2_DIM; ++i) {
        for (j = 0; j < CV2_DIM; ++j) {
          wt_idx = 0;

          int32_t tmp = 0;
          int ifm_idx1 = 0;

          for (m = 0; m < WT2_DIM; ++m) {
            for (n = 0; n < WT2_DIM; ++n) {
              int32_t ifm_value = cast_si32(ifm[ifm_offset + ifm_idx0 + ifm_idx1]);
              int32_t wt_value  = cast_si32(wt[wt_offset + wt_idx]);
              int32_t prod = times(ifm_value, wt_value);
              tmp += prod;

              ifm_idx1 += 1;
              wt_idx   += 1;
            } // n

            ifm_idx1 += P1_DIM - WT2_DIM;
          } // m

          ofm[ofm_offset + ofm_idx] += tmp;

          ofm_idx  += 1;
          ifm_idx0 += 1;
        } // j

        ifm_idx0 += P1_DIM - CV2_DIM;
      } // i

      ifm_offset += P1_SIZE;
      wt_offset  += WT2_SIZE;
    } // d

    ofm_offset += CV2_SIZE;
  } // f
}

int32_t max4(int32_t a, int32_t b, int32_t c, int32_t d) {
  int32_t tmp0 = (a > b) ? a : b;
  int32_t tmp1 = (c > d) ? c : d;
  int32_t result =  (tmp0 > tmp1) ? tmp0 : tmp1;

  return result;
}

// Max Pooling 2D
void pooling_sw_1(int32_t *ifm, int8_t *ofm) {
  
  int d, i, j;
  int ifm_offset = 0;
  int ofm_offset = 0;

  for (d = 0; d < P1_DEPTH; ++d) {
    int ifm_idx = 0;
    int ofm_idx = 0;

    for (i = 0; i < P1_DIM; ++i) {
      for (j = 0; j < P1_DIM; ++j) {
        int32_t tmp0 = ifm[ifm_offset + (ifm_idx << 1) + 0];
        int32_t tmp1 = ifm[ifm_offset + (ifm_idx << 1) + 1];
        int32_t tmp2 = ifm[ifm_offset + (ifm_idx << 1) + CV1_DIM + 0];
        int32_t tmp3 = ifm[ifm_offset + (ifm_idx << 1) + CV1_DIM + 1];

        // ReLU
        tmp0 = (tmp0 > 0) ? tmp0 : 0;
        tmp1 = (tmp1 > 0) ? tmp1 : 0;
        tmp2 = (tmp2 > 0) ? tmp2 : 0;
        tmp3 = (tmp3 > 0) ? tmp3 : 0;

        ofm[ofm_offset + ofm_idx] = (int8_t)max4(tmp0, tmp1, tmp2, tmp3);

        ifm_idx += 1;
        ofm_idx += 1;
      } // j

      ifm_idx += CV1_DIM - P1_DIM;
    } // i

    ifm_offset += CV1_SIZE;
    ofm_offset += P1_SIZE;
  } // d
}

void pooling_sw_2(int32_t *ifm, int8_t *ofm) {
  
  int d, i, j;
  int ifm_offset = 0;
  int ofm_offset = 0;

  for (d = 0; d < P2_DEPTH; ++d) {
    int ifm_idx = 0;
    int ofm_idx = 0;

    for (i = 0; i < P2_DIM; ++i) {
      for (j = 0; j < P2_DIM; ++j) {
        int32_t tmp0 = ifm[ifm_offset + (ifm_idx << 1) + 0];
        int32_t tmp1 = ifm[ifm_offset + (ifm_idx << 1) + 1];
        int32_t tmp2 = ifm[ifm_offset + (ifm_idx << 1) + CV2_DIM + 0];
        int32_t tmp3 = ifm[ifm_offset + (ifm_idx << 1) + CV2_DIM + 1];

        // ReLU
        tmp0 = (tmp0 > 0) ? tmp0 : 0;
        tmp1 = (tmp1 > 0) ? tmp1 : 0;
        tmp2 = (tmp2 > 0) ? tmp2 : 0;
        tmp3 = (tmp3 > 0) ? tmp3 : 0;

        ofm[ofm_offset + ofm_idx] = (int8_t)max4(tmp0, tmp1, tmp2, tmp3);

        ifm_idx += 1;
        ofm_idx += 1;
      } // j

      ifm_idx += CV2_DIM - P2_DIM;
    } // i

    ifm_offset += CV2_SIZE;
    ofm_offset += P2_SIZE;
  } // d
}

// Fully Connection
void fc_sw(int8_t *ifm, int8_t *wt, int32_t *ofm) {

  int f, d, i, j;
  int wt_offset = 0;

  for (f = 0; f < FC_DEPTH; ++f) {
    int ifm_offset = 0;
    int32_t tmp = 0;

    for (d = 0; d < P2_DEPTH; ++d) {
      int ifm_idx = 0;

      for (i = 0; i < P2_DIM; ++i) {
        for (j = 0; j < P2_DIM; ++j) {
          int32_t ifm_value = cast_si32(ifm[ifm_offset + ifm_idx]);
          int32_t wt_value  = cast_si32(wt[wt_offset + ifm_offset + ifm_idx]);
          tmp += times(ifm_value, wt_value);

          ifm_idx += 1;
        }
      }
      ifm_offset += P2_SIZE;
    }
    ofm[f] = tmp;
    wt_offset += ifm_offset;
  }
}

void clamp(int32_t *array, int len) {
  int i;
  for (i = 0; i < len; i++) {
    int32_t value = array[i] >> 9;
    array[i] = (value > 127)  ?  127 :
               (value < -128) ? -128 : value;
  }
}
