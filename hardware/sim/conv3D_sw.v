`timescale 1ns/1ns

module conv3D_sw #(
  parameter IFM_DIM   = 28,
  parameter IFM_DEPTH = 2,
  parameter OFM_DIM   = 24,
  parameter OFM_DEPTH = 2,
  parameter WT_DIM    = 5
) ();

  integer ifm_data[IFM_DEPTH*IFM_DIM*IFM_DIM-1:0];
  integer wt_data[OFM_DEPTH*IFM_DEPTH * WT_DIM*WT_DIM-1:0];
  integer ofm_sw_data[OFM_DEPTH*OFM_DIM*OFM_DIM-1:0];
  integer tmp;

  integer f, d, i, j, m, n;
  initial begin
    #0;
    // init ifm and weight data
    // include neg numbers to test signness
    for (d = 0; d < IFM_DEPTH; d = d + 1) begin
      for (i = 0; i < IFM_DIM; i = i + 1) begin
        for (j = 0; j < IFM_DIM; j = j + 1) begin
          ifm_data[d * IFM_DIM * IFM_DIM + i * IFM_DIM + j] = (d * IFM_DIM * IFM_DIM + i * IFM_DIM + j) % 256 - 128;
        end
      end
    end

    for (f = 0; f < OFM_DEPTH; f = f + 1) begin
      for (d = 0; d < IFM_DEPTH; d = d + 1) begin
        for (m = 0; m < WT_DIM; m = m + 1) begin
          for (n = 0; n < WT_DIM; n = n + 1) begin
            wt_data[f * IFM_DEPTH * WT_DIM * WT_DIM + d * WT_DIM * WT_DIM + m * WT_DIM + n] = (n % 2 == 0) ? -(f + d + m + n) : (f + d + m + n);
          end
        end
      end
    end

    for (f = 0; f < OFM_DEPTH; f = f + 1) begin
      for (i = 0; i < OFM_DIM; i = i + 1) begin
        for (j = 0; j < OFM_DIM; j = j + 1) begin
          ofm_sw_data[f * OFM_DIM * OFM_DIM + i * OFM_DIM + j] = 0;
        end
      end
    end
  end

  initial begin
    #1;
    // Software implementation of conv3D
    for (f = 0; f < OFM_DEPTH; f = f + 1) begin
      for (d = 0; d < IFM_DEPTH; d = d + 1) begin
        for (i = 0; i < OFM_DIM; i = i + 1) begin
          for (j = 0; j < OFM_DIM; j = j + 1) begin
            tmp = 0;

            for (m = 0; m < WT_DIM; m = m + 1) begin
              for (n = 0; n < WT_DIM; n = n + 1) begin
                tmp = tmp +
                  ifm_data[d * IFM_DIM * IFM_DIM + (i + m) * IFM_DIM + (j + n)] *
                  wt_data[f * IFM_DEPTH * WT_DIM * WT_DIM + d * WT_DIM * WT_DIM + m * WT_DIM + n];
              end // m
            end // n
            ofm_sw_data[f * OFM_DIM * OFM_DIM + i * OFM_DIM + j] = ofm_sw_data[f * OFM_DIM * OFM_DIM + i * OFM_DIM + j] + tmp;

          end // j
        end // i
      end // d
    end // f
  end

endmodule
