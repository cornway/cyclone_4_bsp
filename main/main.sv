
module project
#(parameter simulation = 0)
(
    input logic clk_50MHz,

    input logic button_a_i,
    input logic button_b_i,
    input logic button_c_i,
    input logic button_d_i,

    output logic buzz_o,
    output logic led_a_o,
    output logic led_b_o,
    output logic led_c_o,
    output logic led_d_o,

    sdram_phy_if_t sdram_phy,

    output logic[7:0] lcd_seg,
    output logic[3:0] lcd_dig,

    output logic[3:0] switch,

    input logic spi2_sck,
    input logic spi2_cs,
    input logic spi2_mosi,
    output logic spi2_miso,

    input logic clk_sim_200MHz,
    input logic clk_sim_4MHz
);

    logic pll_locked, pll2_locked;

    logic por_reset;

    logic clk_pll_200MHz;
    logic clk_200MHz;

    logic clk_pll_4MHz;
    logic clk_4MHz;

    logic clk_100MHz = '0;
    logic clk_25MHz = '0;

    logic button_a;

    wire reset = por_reset;

    assign clk_200MHz = simulation ? clk_sim_200MHz : clk_pll_200MHz;
    assign clk_4MHz = simulation ? clk_sim_4MHz : clk_pll_4MHz;

    always_ff @(posedge clk_50MHz) clk_25MHz <= ~clk_25MHz;
    always_ff @(posedge clk_200MHz) clk_100MHz <= ~clk_100MHz;

    mod_por por
        (
            .clk_i  (clk_50MHz),
            .rst_o  (por_reset)
         );

    assign device_ready = simulation ? '1 : pll_locked && pll2_locked;

    pll pll_200MHz
        (
            .areset     (por_reset),
            .inclk0     (clk_50MHz),
            .c0         (clk_pll_200MHz),
            .locked     (pll_locked)
        );
    pll2 pll_4MmHz
        (
            .areset     (por_reset),
            .inclk0     (clk_50MHz),
            .c0         (clk_pll_4MHz),
            .locked     (pll2_locked)
        );

    logic buz_trig = '0;
    logic buz_busy;
    assign led_a_o = !buz_busy;

    mod_buzzer
    #(
        .simulation(simulation)
    ) buzzer (
            .clk_4M_i       (clk_4MHz),
            .period_ms_i    (simulation ? 10 : 600),
            .trig_i         (buz_trig),
            .rst_i          (por_reset),
            .cyc_o          (buz_busy),
            .pin_o          (buzz_o)
        );

    mod_button mod_button_a
        (
            .clk_i          (clk_4MHz),
            .pin_i          (button_a_i),
            .pin_o          (button_a)
        );

    always_ff @ (posedge clk_4MHz) begin
        if (!buz_busy) begin
            buz_trig <= button_a;
        end else begin
            buz_trig <= '0;
        end
    end

    logic mb_trig = '0;
    logic mb_cyc;
    logic mb_stb;
    logic mb_we_i = '0;
    logic mb_seq = '0, mb_seq_ack;
    logic[15:0] mb_length = '0;
    logic[31:0] mb_addr = '0;
    logic[15:0] mb_data = '0;
    logic[15:0] mb_data_o;

    mem_wif_t mb_mem_wif();
    mem_wif_t mem_wif();
    mem_wif_t spi_mem_wif();
    mem_wif_t a_mem_wif();
    mem_wif_t mem_user_3();

    assign mem_wif.clk_i = clk_50MHz;

    wishbus_4 wishbus_4_inst
        (
            .mem(mem_wif),
            .user_0(a_mem_wif),
            .user_1(spi_mem_wif),
            .user_2(mb_mem_wif),
            .user_3(mem_user_3),

            .user_en(4'b0111)
        );

    sdram_wish_if sdram_wish_if_inst
        (
            .wif(mem_wif),
            .phy(sdram_phy)
        );

    spi_phy_if spi2_phy_if();
    spi_host_if spi2_host_if();

    assign spi2_phy_if.sck = spi2_sck;
    assign spi2_phy_if.cs = spi2_cs;
    assign spi2_phy_if.mosi = spi2_mosi;
    assign spi2_miso = spi2_phy_if.miso;

    assign spi2_host_if.clk_i = clk_50MHz;

    spi_16bit_slave spi_16bit_slave_2
        (
            .phy(spi2_phy_if),
            .spi_host(spi2_host_if),

            .conf_cpol('0),
            .conf_dir('0),
            .conf_cpha('0)
        );

    a_mix_wif_t a_mix_wif();

    audio_mixer_8_16bps audio_mixer_8_16bps_inst
    (
        .wif(a_mix_wif),
        .mem(a_mem_wif)
    );

    logic[7:0] spi_io_addr;

    logic[31:0] mem_addr = '0;
    logic[31:0] mem_dat = '0;

    enum logic[4 : 0]
        {state_idle,
        state_read,
        state_write,
        state_mem_burst_init,
        state_mem_burst_start,
        state_mem_burst_next,
        state_mem_burst_start_ack,
        state_mem_burst_next_ack,
        state_mem_addr_lo,
        state_mem_addr_hi,
        state_mem_dat_lo,
        state_mem_read,
        state_mem_read_ack,
        state_mem_read_ack2,
        state_mem_write,
        state_mem_write_ack,
        state_mix_wr_master_addr,
        state_mix_wr_master_len,
        state_mix_wr_addr,
        state_mix_wr_dat_lo,
        state_mix_wr_dat_hi,
        state_mix_wait_ack,
        state_mix_rd_addr,
        state_mix_rd_ack
        } spi2_state = state_idle,
          spi2_state_next = state_idle;

    wire[7:0] spi2_ctl = spi2_host_if.dat_i[15:8];
    assign spi_mem_wif.rst_i = reset;
    assign a_mix_wif.rst_i = reset;
    assign a_mix_wif.clk_i = mem_wif.clk_i;

    always_ff @(posedge clk_50MHz) begin
        if (reset) begin
            spi2_state <= state_idle;

            spi_mem_wif.dat_o <= '0;
            spi_mem_wif.addr_i <= '0;
            spi_mem_wif.stb_i <= '0;
            spi_mem_wif.we_i <= '1;
            spi_mem_wif.sel_i <= '1;

            a_mix_wif.dat_i <= '0;
            a_mix_wif.addr_i <= '0;
            a_mix_wif.stb_i <= '0;
            a_mix_wif.we_i <= '1;

            mb_stb <= '0;

        end else if (spi2_host_if.wr_req_ack) begin
            case (spi2_state)
                state_idle:
                    case (spi2_ctl)
                        8'h80: begin
                            spi_io_addr <= spi2_host_if.dat_i[7:0];
                            spi2_state <= state_read;
                        end
                        8'hC0: begin
                            spi2_state <= state_mem_addr_lo;
                            spi2_state_next <= state_mem_read;
                        end
                        8'hC1: begin
                            spi2_state <= state_mem_addr_lo;
                            spi2_state_next <= state_mem_dat_lo;
                        end
                        8'h90: begin
                            spi2_state <= state_mix_rd_addr;
                        end
                        8'h91: begin
                            spi2_state <= state_mix_wr_addr;
                        end
                        8'hD0: begin
                            mb_we_i <= '1;
                            spi2_state <= state_mem_burst_init;
                        end
                        8'hD1: begin
                            mb_we_i <= '0;
                            spi2_state <= state_mem_burst_init;
                        end
                        default: begin
                        end
                    endcase
                state_mem_burst_init: begin
                    mb_length <= spi2_host_if.dat_i;
                    spi2_state_next <= state_mem_burst_start;
                    spi2_state <= state_mem_addr_lo;
                end
                state_mem_burst_next: begin
                    if (!mb_cyc) begin
                        spi2_state <= state_idle;
                    end else begin 
                        mb_seq <= '1;
                        mb_data <= spi2_host_if.dat_i;
                        spi2_state <= state_mem_burst_next_ack;
                    end
                end
                state_mix_rd_addr: begin
                    a_mix_wif.addr_i <= spi2_host_if.dat_i[7:0];
                    a_mix_wif.stb_i <= '1;
                    spi2_state <= state_mix_rd_ack;
                end
                state_mix_wr_addr: begin
                    a_mix_wif.addr_i <= spi2_host_if.dat_i[7:0];
                    spi2_state <= state_mix_wr_dat_lo;
                end
                state_mix_wr_dat_lo: begin
                    a_mix_wif.dat_i[15:0] <= spi2_host_if.dat_i;
                    spi2_state <= state_mix_wr_dat_hi;
                end
                state_mix_wr_dat_hi: begin
                    a_mix_wif.dat_i[31:16] <= spi2_host_if.dat_i;
                    a_mix_wif.stb_i <= '1;
                    a_mix_wif.we_i <= '0;
                    spi2_state <= state_mix_wait_ack;
                end
                state_mem_addr_lo: begin
                    mem_addr[15:0] <= spi2_host_if.dat_i;
                    spi2_state <= state_mem_addr_hi;
                end
                state_mem_addr_hi: begin
                    mem_addr[31:16] <= spi2_host_if.dat_i;
                    spi2_state <= spi2_state_next;
                end
                state_mem_dat_lo: begin
                    spi2_state <= state_mem_write;
                    mem_dat[15:0] <= spi2_host_if.dat_i;
                end
                state_read: begin
                    spi2_state <= state_idle;
                end
                state_write: begin
                    spi2_state <= state_idle;
                end
            endcase
        end else case (spi2_state)
            state_mem_burst_start: begin
                if (!mb_cyc) begin
                    mb_addr <= mem_addr;
                    mb_stb <= '1;
                    spi2_state <= state_mem_burst_start_ack;
                end
            end
            state_mem_burst_next: begin
                if (!mb_cyc) begin
                    spi2_state <= state_idle;
                end
            end
            state_mem_burst_start_ack: begin
                if (mb_cyc) begin
                    mb_stb <= '0;
                    spi2_state <= state_mem_burst_next;
                end
            end
            state_mem_burst_next_ack: begin
                if (mb_seq_ack) begin
                    mb_seq <= '0;
                    mem_dat[15:0] <= mb_data_o;
                    spi2_state <= state_mem_burst_next;
                end
            end
            state_mix_rd_ack: begin
                a_mix_wif.stb_i <= '0;
                if (a_mix_wif.stb_o) begin
                    mem_dat <= a_mix_wif.dat_o;
                    spi2_state <= state_idle;
                end
            end
            state_mix_wait_ack: begin
                a_mix_wif.stb_i <= '0;
                if (a_mix_wif.stb_o) begin
                    a_mix_wif.we_i <= '1;
                    spi2_state <= state_idle;
                end
            end
            state_mem_write: begin
                if (!spi_mem_wif.cyc_o) begin
                    if (spi_mem_wif.ack_o) begin
                        spi_mem_wif.sel_i <= '1;
                        spi_mem_wif.addr_i <= mem_addr;
                        spi_mem_wif.dat_o <= mem_dat[15:0];
                        spi_mem_wif.stb_i <= '1;
                        spi_mem_wif.we_i <= '0;
                        spi2_state <= state_mem_write_ack;
                    end else begin
                        spi_mem_wif.sel_i <= '0;
                    end
                end
            end
            state_mem_write_ack: begin
                if (spi_mem_wif.stb_o) begin
                    spi_mem_wif.we_i <= '1;
                    spi_mem_wif.addr_i <= '0;
                    spi_mem_wif.dat_o <= '0;
                    spi2_state <= state_idle;
                end
            end
            state_mem_read: begin
                if (!spi_mem_wif.cyc_o) begin
                    if (spi_mem_wif.ack_o) begin
                        spi_mem_wif.sel_i <= '1;
                        spi_mem_wif.addr_i <= mem_addr;
                        spi_mem_wif.stb_i <= '1;
                        spi2_state <= state_mem_read_ack;
                    end else begin
                        spi_mem_wif.sel_i <= '0;
                    end
                end
            end
            state_mem_read_ack: begin
                if (spi_mem_wif.stb_o) begin
                    spi2_state <= state_mem_read_ack2;
                end
            end
            state_mem_read_ack2: begin
                if (!spi_mem_wif.cyc_o) begin
                    mem_dat[15:0] <= spi_mem_wif.dat_i;
                    spi_mem_wif.addr_i <= '0;
                    spi2_state <= state_idle;
                end
            end
        endcase

        spi2_host_if.wr_req_ack <= spi2_host_if.wr_req;
        if (spi_mem_wif.stb_i)
            spi_mem_wif.stb_i <= '0;
    end

    always_comb begin
        if (mb_cyc) begin
            spi2_host_if.dat_o = mem_dat[15:0];
        end else case (spi_io_addr)
            8'h00:
                spi2_host_if.dat_o = 16'h1234;
            8'h01:
                spi2_host_if.dat_o = 16'h5678;
            8'h02:
                spi2_host_if.dat_o = 16'h9abcd;
            8'h03:
                spi2_host_if.dat_o = 16'hef01;
            8'h04:
                spi2_host_if.dat_o = mem_dat[15:0];
            8'h05:
                spi2_host_if.dat_o = mem_dat[31:16];
            default:
                spi2_host_if.dat_o = '0;
        endcase
    end

    mem_burst_if mem_burst_if_inst
        (
            .clk_i(mem_wif.clk_i),
            .stb_i(mb_stb),
            .seq_i(mb_seq),
            .rst_i(reset),
            .we_i(mb_we_i),
            .cyc_o(mb_cyc),
            .seq_o(mb_seq_ack),
            .len_i(mb_length),
            .dat_i(mb_data),
            .dat_o(mb_data_o),
            .addr_i(mb_addr),

            .mem(mb_mem_wif)
        );

endmodule

module mem_burst_if
(
    input logic clk_i,
    input logic stb_i,
    input logic seq_i,
    input logic rst_i,
    input logic we_i,
    output logic cyc_o,
    output logic seq_o,
    input logic[15:0] len_i,
    input logic[15:0] dat_i,
    output logic[15:0] dat_o,
    input logic[31:0] addr_i,

    mem_wif_t.dev mem
);

enum logic[2:0] {
    state_idle,
    state_init,
    state_seq,
    state_req,
    state_ack,
    state_ack2,
    state_ack3,
    state_done
} mb_state = state_idle;

logic we_i_reg = '0;
logic[31:0] addr_reg = '0;
logic[15:0] data_reg = '0;
logic[15:0] data_len = '0;

assign mem.rst_i = rst_i;

always_ff @(posedge clk_i, posedge rst_i) begin
    if (rst_i) begin
        mb_state <= state_idle;
        dat_o <= '0;
        data_reg <= '0;
        data_len <= '0;
        we_i_reg <= '0;
        addr_reg <= '0;
        seq_o <= '0;
        cyc_o <= '0;

        mem.stb_i <= '0;
        mem.we_i <= '1;
        mem.sel_i <= '1;
        mem.dat_o <= '0;
        mem.addr_i <= '0;

    end else begin
        case (mb_state)
            state_idle: begin
                if (stb_i) begin
                    data_len <= len_i;
                    addr_reg <= addr_i;
                    we_i_reg <= we_i;
                    cyc_o <= '1;
                    mb_state <= state_seq;
                end
            end
            state_seq: begin
                if (seq_i) begin
                    data_reg <= dat_i;
                    data_len <= data_len - 1'b1;
                    addr_reg <= addr_reg + 1'b1;
                    mb_state <= state_req;
                end
            end
            state_req: begin
                if (!mem.cyc_o) begin
                    if (mem.ack_o) begin
                        mem.sel_i <= '1;
                        mem.stb_i <= '1;
                        mem.we_i <= we_i_reg;
                        mem.addr_i <= addr_reg;
                        if (!we_i_reg) 
                            mem.dat_o <= data_reg;
                        mb_state <= state_ack;
                    end else begin
                        mem.sel_i <= '0;
                    end
                end
            end
            state_ack: begin
                if (mem.stb_o) begin
                    mem.stb_i <= '0;
                    mb_state <= state_ack2;
                end
            end
            state_ack2: begin
                if (!mem.cyc_o) begin
                    if (we_i_reg)
                        data_reg <= mem.dat_i;
                    seq_o <= '1;
                    mem.dat_o <= '0;
                    mem.addr_i <= '0;
                    mem.we_i <= '1;
                    if (data_len)
                        mb_state <= state_ack3;
                    else begin
                        mb_state <= state_done;
                    end
                end
            end
            state_ack3: begin
                if (!seq_i) begin
                    seq_o <= '0;
                    mb_state <= state_seq;
                end
            end
            state_done: begin
                if (!seq_i) begin
                    cyc_o <= '0;
                    seq_o <= '0;
                    mb_state <= state_idle;
                end
            end
        endcase
    end
end

endmodule
