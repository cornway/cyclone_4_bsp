
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

    mem_wif_t mem_wif();
    mem_wif_t spi_mem_wif();
    mem_wif_t a_mem_wif();
    mem_wif_t mem_user_2();
    mem_wif_t mem_user_3();

    assign mem_wif.clk_i = clk_50MHz;

    wishbus_4 wishbus_4_inst
        (
            .mem(mem_wif),
            .user_0(a_mem_wif),
            .user_1(spi_mem_wif),
            .user_2(mem_user_2),
            .user_3(mem_user_3),

            .user_en(4'b0011)
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
    logic[31:0] mem_dat;

    enum logic[4 : 0]
        {state_idle,
        state_read,
        state_write,
        state_mem_addr_lo,
        state_mem_addr_hi,
        state_mem_dat_lo,
        state_mem_read,
        state_mem_read_ack,
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
                        default: begin
                        end
                    endcase
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
                    mem_dat <= spi2_host_if.dat_i;
                end
                state_read: begin
                    spi2_state <= state_idle;
                end
                state_write: begin
                    spi2_state <= state_idle;
                end
            endcase
        end else case (spi2_state)
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
                        spi_mem_wif.dat_o <= mem_dat;
                        spi_mem_wif.stb_i <= '1;
                        spi_mem_wif.we_i <= '0;
                        spi2_state <= state_mem_write_ack;
                    end else begin
                        spi_mem_wif.sel_i <= '0;
                    end
                end
            end
            state_mem_write_ack: begin
                if (!spi_mem_wif.cyc_o) begin
                    spi_mem_wif.we_i <= '1;
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
                if (!spi_mem_wif.cyc_o) begin
                    mem_dat <= {16'h0, spi_mem_wif.dat_i};
                    spi2_state <= state_idle;
                end
            end
        endcase

        spi2_host_if.wr_req_ack <= spi2_host_if.wr_req;
        if (spi_mem_wif.stb_i)
            spi_mem_wif.stb_i <= '0;
    end

    always_comb begin
        case (spi_io_addr)
            8'h00:
                spi2_host_if.dat_o = 16'h1234;
            8'h04:
                spi2_host_if.dat_o = mem_dat[15:0];
            8'h05:
                spi2_host_if.dat_o = mem_dat[31:16];
            default:
                spi2_host_if.dat_o = '0;
        endcase
    end

endmodule
