
// From the ARM init program
#define WT_CONV1_DDR_ADDR 0x109d6c
#define WT_CONV2_DDR_ADDR 0x109e34
#define WT_FC_DDR_ADDR    0x10aab4
#define IMAGES_DDR_ADDR   0x10b4b4
#define LABELS_DDR_ADDR   0x8855b4

#define IMG_DIM   28
#define IMG_DEPTH 1

#define IMG_SIZE (IMG_DIM * IMG_DIM)

#define WT1_DIM  5

#define WT1_SIZE (WT1_DIM * WT1_DIM)

#define CV1_DIM (IMG_DIM - WT1_DIM + 1)
#define CV1_DEPTH 8

#define CV1_SIZE (CV1_DIM * CV1_DIM)

#define CONV1_OFM_SIZE (CV1_DEPTH * CV1_SIZE)

// ===

#define P1_DIM   (CV1_DIM / 2)
#define P1_DEPTH (CV1_DEPTH)

#define P1_SIZE (P1_DIM * P1_DIM)

#define POOL1_OFM_SIZE (P1_DEPTH * P1_SIZE)

#define WT2_DIM   5

#define WT2_SIZE (WT2_DIM * WT2_DIM)

#define CV2_DIM (P1_DIM - WT2_DIM + 1)
#define CV2_DEPTH 16

#define CV2_SIZE (CV2_DIM * CV2_DIM)

#define CONV2_OFM_SIZE (CV2_DEPTH * CV2_DIM * CV2_DIM)

// ===

#define P2_DIM (CV2_DIM / 2)
#define P2_DEPTH (CV2_DEPTH)

#define P2_SIZE (P2_DIM * P2_DIM)

#define POOL2_OFM_SIZE (P2_DEPTH * P2_SIZE)

#define WT3_DIM  (P2_DIM) // 4

#define WT3_SIZE (WT3_DIM * WT3_DIM)

#define FC_DIM 1
#define FC_DEPTH 10

#define FC_SIZE (FC_DIM * FC_DIM)
#define FC_OFM_SIZE (FC_DEPTH * FC_DIM * FC_DIM)

// ===

#define WT_CONV1_SIZE (CV1_DEPTH * IMG_DEPTH * WT1_DIM * WT1_DIM) // 200
#define WT_CONV2_SIZE (CV2_DEPTH * P1_DEPTH * WT1_DIM * WT2_DIM)  // 3200
#define WT_FC_SIZE    (FC_DEPTH * P2_DEPTH * WT3_DIM * WT3_DIM)   // 2560

void conv3D_sw_1(int8_t *ifm, int8_t *wt, int32_t *ofm);
void conv3D_sw_2(int8_t *ifm, int8_t *wt, int32_t *ofm);
void pooling_sw_1(int32_t *ifm, int8_t *ofm);
void pooling_sw_2(int32_t *ifm, int8_t *ofm);
void fc_sw(int8_t *ifm, int8_t *wt, int32_t *ofm);
void clamp(int32_t *array, int len);
int32_t cast_si32(int8_t input);
