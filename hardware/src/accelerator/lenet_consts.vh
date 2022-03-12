
`define IMG_DIM 28
`define IMG_SIZE (`IMG_DIM * `IMG_DIM) // 784

`define WT1_DIM   5
`define WT1_DEPTH 1
`define NUM_WT1   8

`define WT1_SIZE     (`WT1_DIM * `WT1_DIM)

`define CV1_DIM      (`IMG_DIM - `WT1_DIM + 1) // 24

`define CV1_OFM_SIZE (`NUM_WTS1 * `CV1_DIM * `CV1_DIM)

`define P1_DIM       (`CV1_DIM / 2) // 12

`define P1_OFM_SIZE  (`NUM_WTS1 * `P1_DIM * `P1_DIM)

`define WT2_DIM   5
`define WT2_DEPTH (`NUM_WTS1)
`define NUM_WT2   16

`define CV2_DIM      (`P1_DIM - `WT2_DIM + 1) // 8

`define CV2_OFM_SIZE (`NUM_WTS2 * `CV2_DIM * `CV2_DIM)

`define P2_DIM       (`CV2_DIM / 2) // 4

`define P2_OFM_SIZE  (`NUM_WTS2 * `P2_DIM * `P2_DIM)

`define WT3_DIM   (`P2_DIM)
`define WT3_DEPTH (`NUM_WTS2)
`define NUM_WT3   10

`define WT_CONV1_SIZE (`NUM_WTS1 * `WT1_DEPTH * `WT1_DIM * `WT1_DIM) // 200
`define WT_CONV2_SIZE (`NUM_WTS2 * `WT2_DEPTH * `WT2_DIM * `WT2_DIM) // 3200
`define WT_FC_SIZE    (`NUM_WTS3 * `WT3_DEPTH * `WT3_DIM * `WT3_DIM) // 2560

