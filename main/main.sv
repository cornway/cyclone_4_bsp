
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

    logic clk_2MHz = '0;
    logic clk_1MHz = '0;

    logic button_a;
    logic button_b;
    logic button_c;
    logic button_d;

    wire device_ready = simulation ? '1 : pll_locked && pll2_locked;
    wire reset = por_reset | ~device_ready;

    logic clk_1KHz = '0;
    logic[9:0] clk_1KHz_cnt = '0;

    logic clk_1Hz = '0;
    logic[9:0] clk_1Hz_cnt = '0;

    logic[15:0] dt_dbg;
    assign clk_200MHz = simulation ? clk_sim_200MHz : clk_pll_200MHz;
    assign clk_4MHz = simulation ? clk_sim_4MHz : clk_pll_4MHz;

    always_ff @(posedge clk_50MHz) clk_25MHz <= ~clk_25MHz;
    always_ff @(posedge clk_200MHz) clk_100MHz <= ~clk_100MHz;

    always_ff @(posedge clk_4MHz) clk_2MHz <= ~clk_2MHz;
    always_ff @(posedge clk_2MHz) clk_1MHz <= ~clk_1MHz;

    mod_por por
        (
            .clk_i  (clk_50MHz),
            .rst_o  (por_reset)
         );

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

    assign buzz_o = ~button_a;

    mod_button mod_button_a
        (
            .clk_i          (clk_50MHz),
            .pin_i          (button_a_i),
            .evt_o          (button_a)
        );
    mod_button mod_button_b
        (
            .clk_i          (clk_50MHz),
            .pin_i          (button_b_i),
            .evt_o          (button_b)
        );
    mod_button mod_button_c
        (
            .clk_i          (clk_50MHz),
            .pin_i          (button_c_i),
            .evt_o          (button_c)
        );
    mod_button mod_button_d
        (
            .clk_i          (clk_50MHz),
            .pin_i          (button_d_i),
            .evt_o          (button_d)
        );

    always_ff @(posedge clk_1MHz) begin
        if (clk_1KHz_cnt == 10'd500) begin
            clk_1KHz_cnt <= '0;
            clk_1KHz <= ~clk_1KHz;
        end else begin
            clk_1KHz_cnt <= clk_1KHz_cnt + 1'b1;
        end
    end

    always_ff @(posedge clk_1KHz) begin
        if (clk_1Hz_cnt == 10'd500) begin
            clk_1Hz_cnt <= '0;
            clk_1Hz <= ~clk_1Hz;
        end else begin
            clk_1Hz_cnt <= clk_1Hz_cnt + 1'b1;
        end
    end

    digital_tube_8x4_static digital_tube_8x4_static_inst
        (
            .clk_1KHz(clk_1KHz),
            .rst_i(reset),
            .dig_i(dt_dbg),
            .seg_o(lcd_seg),
            .dig_o(lcd_dig)
        );

    assign led_a_o = ~button_a_i;
    assign led_b_o = ~button_b_i;
    assign led_c_o = ~button_c_i;
    assign led_d_o = ~button_d_i;

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
    mem_wif_t mem_fcpu();
    mem_wif_t mem_fcpu_reg();
    mem_wif_t mem_fcpu_ram();
    //mem_wif_t mem_dummy();

    assign mem_wif.clk_i = clk_50MHz;
    assign sdram_phy.Clk = clk_50MHz;
    assign mem_fcpu.clk_i = clk_50MHz;

    wishbus_4 wishbus_4_inst
        (
            .mem(mem_wif),
            .user_0(a_mem_wif),
            .user_1(spi_mem_wif),
            .user_2(mb_mem_wif),
            .user_3(mem_fcpu_ram),

            .user_en(4'b1111)
        );

    logic[1:0] fxcpu_addr_space;
    wishbus_1to2 wishbus_1to2_inst
        (
            .mem_1(mem_fcpu_ram),
            .mem_2(mem_fcpu_reg),
            .user(mem_fcpu),
            .mem_en(fxcpu_addr_space[1])
        );

    //assign mem_fcpu_ram.rst_i = reset;//mem_fcpu.rst_i;
    assign mem_fcpu.ack_o = mem_fcpu_ram.ack_o;
    //assign mem_fcpu_reg.ack_o = '1;

    logic fxcpu16_reset = '0;
    fxcpu16 fxcpu16_inst
        (
            .mem(mem_fcpu),
            .rst_i(reset | fxcpu16_reset),
            .addr_space(fxcpu_addr_space),
        );

    mem_wif_t ram_wif();
    mem_wif_t sdram_wif();

    assign sdram_wif.clk_i = clk_50MHz;
    assign ram_wif.clk_i = clk_50MHz;

    wishbus_1to2 wishbus_1to2_inst_2
        (
            .mem_1(sdram_wif),
            .mem_2(ram_wif),
            .user(mem_wif),
            .mem_en(fxcpu_addr_space[0] | mem_wif.addr_i[30])
        );
    assign sdram_wif.rst_i = mem_wif.rst_i;
    assign ram_wif.rst_i = mem_wif.rst_i;

    sdram_wish_if sdram_wish_if_inst
        (
            .wif(sdram_wif),
            .phy(sdram_phy)
        );

    ram_phy_t ram_phy();

    ram_2_wishbus ram_2_wishbus_inst
        (
            .phy(ram_phy),
            .mem(ram_wif)
        );

    ram_2port ram_2port_inst
        (
            .data(ram_phy.data),
            .rdaddress(ram_phy.rdaddress),
            .rdclock(ram_phy.rdclock),
            .wraddress(ram_phy.wraddress),
            .wrclock(ram_phy.wrclock),
            .wren(ram_phy.wren),
            .q(ram_phy.q)
        );

    spi_phy_if spi2_phy_if();
    spi_host_if spi2_host_if();

    assign spi2_phy_if.sck = spi2_sck;
    assign spi2_phy_if.cs = spi2_cs;
    assign spi2_phy_if.mosi = spi2_mosi;
    assign spi2_miso = spi2_phy_if.miso;

    assign spi2_host_if.clk_i = clk_50MHz;
    assign spi2_host_if.reset = reset;

    a_mix_wif_t a_mix_wif();

    audio_mixer_8_16bps audio_mixer_8_16bps_inst
    (
        .wif(a_mix_wif),
        .mem(a_mem_wif)
    );

    logic[31:0] mem_addr = '0;
    logic[31:0] mem_dat = '0;

    assign spi_mem_wif.rst_i = reset;
    assign a_mix_wif.rst_i = reset;
    //assign mem_spi2_wif.rst_i = reset;
    assign a_mix_wif.clk_i = mem_wif.clk_i;

    mem_wif_t mem_internal();
    mem_wif_t mem_spi2_wif();
    mem_wif_t mem_dummy1();
    mem_wif_t  mem_dummy2();

    spi_host_2_wif spi_host_2_wif_inst
        (
            .spi(spi2_host_if),
            .mem(mem_spi2_wif),
            .spi_rd_cmd(8'h80)
        );

    assign mem_internal.clk_i = clk_50MHz;

    wishbus_4 wishbus_4_inst_2
        (
            .mem(mem_internal),
            .user_0(mem_fcpu_reg),
            .user_1(mem_spi2_wif),
            .user_2(mem_dummy1),
            .user_3(mem_dummy2),

            .user_en(4'b0011)
        );

    enum logic[4 : 0]
        {state_int_idle,
        state_int_mburst_init,
        state_int_mburst_start,
        state_int_mburst_next,
        state_int_mburst_start_ack,
        state_int_mburst_next_ack,
        state_int_addr_lo,
        state_int_addr_hi,
        state_int_dat_lo,
        state_int_mem_read,
        state_int_mem_read_ack,
        state_int_mem_read_ack2,
        state_int_mem_write,
        state_int_mem_write_ack,
        state_int_mix_wr_addr,
        state_int_mix_wr_dat_lo,
        state_int_mix_wr_dat_hi,
        state_int_mix_wait_ack,
        state_int_mix_rd_addr,
        state_int_mix_rd_ack
        } int_state = state_int_idle,
          int_state_next = state_int_idle;

    always_ff @(posedge clk_50MHz) begin
        if (reset) begin
            int_state <= state_int_idle;

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

            mem_internal.stb_o <= '0;
            mem_internal.cyc_o <= '0;
            mem_internal.dat_i <= '0;

            fxcpu16_reset <= '1;

        end else if (!mem_internal.stb_o && mem_internal.stb_i && !mem_internal.we_i) begin
            mem_internal.stb_o <= '1;
            mem_internal.cyc_o <= '1;
            case (int_state)
                state_int_idle:
                    case (mem_internal.dat_o[15:8])
                        8'hC0: begin
                            int_state <= state_int_addr_lo;
                            int_state_next <= state_int_mem_read;
                        end
                        8'hC1: begin
                            int_state <= state_int_addr_lo;
                            int_state_next <= state_int_dat_lo;
                        end
                        8'h90: begin
                            int_state <= state_int_mix_rd_addr;
                        end
                        8'h91: begin
                            int_state <= state_int_mix_wr_addr;
                        end
                        8'hD0: begin
                            mb_we_i <= '1;
                            int_state <= state_int_mburst_init;
                        end
                        8'hD1: begin
                            mb_we_i <= '0;
                            int_state <= state_int_mburst_init;
                        end
                        8'h10: begin
                            fxcpu16_reset <= ~mem_internal.dat_o[0];
                        end
                        8'h20: begin
                            dt_dbg <= mem_internal.dat_o;
                        end
                        default: begin
                        end
                    endcase
                state_int_mburst_init: begin
                    mb_length <= mem_internal.dat_o;
                    int_state_next <= state_int_mburst_start;
                    int_state <= state_int_addr_lo;
                end
                state_int_mburst_next: begin
                    if (!mb_cyc) begin
                        int_state <= state_int_idle;
                    end else begin 
                        mb_seq <= '1;
                        mb_data <= mem_internal.dat_o;
                        int_state <= state_int_mburst_next_ack;
                    end
                end
                state_int_mix_rd_addr: begin
                    a_mix_wif.addr_i <= mem_internal.dat_o[7:0];
                    a_mix_wif.stb_i <= '1;
                    int_state <= state_int_mix_rd_ack;
                end
                state_int_mix_wr_addr: begin
                    a_mix_wif.addr_i <= mem_internal.dat_o[7:0];
                    int_state <= state_int_mix_wr_dat_lo;
                end
                state_int_mix_wr_dat_lo: begin
                    a_mix_wif.dat_i[15:0] <= mem_internal.dat_o;
                    int_state <= state_int_mix_wr_dat_hi;
                end
                state_int_mix_wr_dat_hi: begin
                    a_mix_wif.dat_i[31:16] <= mem_internal.dat_o;
                    a_mix_wif.stb_i <= '1;
                    a_mix_wif.we_i <= '0;
                    int_state <= state_int_mix_wait_ack;
                end
                state_int_addr_lo: begin
                    mem_addr[15:0] <= mem_internal.dat_o;
                    int_state <= state_int_addr_hi;
                end
                state_int_addr_hi: begin
                    mem_addr[31:16] <= mem_internal.dat_o;
                    int_state <= int_state_next;
                end
                state_int_dat_lo: begin
                    int_state <= state_int_mem_write;
                    mem_dat[15:0] <= mem_internal.dat_o;
                end
            endcase
        end else if (!mem_internal.stb_o && mem_internal.stb_i && mem_internal.we_i) begin
            mem_internal.stb_o <= '1;
            mem_internal.cyc_o <= '1;
            if (mb_cyc) begin
                mem_internal.dat_i = mem_dat[15:0];
            end else case (mem_internal.addr_i)
                8'h00:
                    mem_internal.dat_i <= 16'h1234;
                8'h01:
                    mem_internal.dat_i <= 16'h5678;
                8'h02:
                    mem_internal.dat_i <= 16'h9abcd;
                8'h03:
                    mem_internal.dat_i <= 16'hef01;
                8'h04:
                    mem_internal.dat_i <= mem_dat[15:0];
                8'h05:
                    mem_internal.dat_i <= mem_dat[31:16];
                default:
                    mem_internal.dat_i = '0;
            endcase
        end else begin
            mem_internal.cyc_o <= '0;
            mem_internal.stb_o <= '0;
            case (int_state)
                state_int_mburst_start: begin
                    if (!mb_cyc) begin
                        mb_addr <= mem_addr;
                        mb_stb <= '1;
                        int_state <= state_int_mburst_start_ack;
                    end
                end
                state_int_mburst_next: begin
                    if (!mb_cyc) begin
                        int_state <= state_int_idle;
                    end
                end
                state_int_mburst_start_ack: begin
                    if (mb_cyc) begin
                        mb_stb <= '0;
                        int_state <= state_int_mburst_next;
                    end
                end
                state_int_mburst_next_ack: begin
                    if (mb_seq_ack) begin
                        mb_seq <= '0;
                        mem_dat[15:0] <= mb_data_o;
                        int_state <= state_int_mburst_next;
                    end
                end
                state_int_mix_rd_ack: begin
                    a_mix_wif.stb_i <= '0;
                    if (a_mix_wif.stb_o) begin
                        mem_dat <= a_mix_wif.dat_o;
                        int_state <= state_int_idle;
                    end
                end
                state_int_mix_wait_ack: begin
                    a_mix_wif.stb_i <= '0;
                    if (a_mix_wif.stb_o) begin
                        a_mix_wif.we_i <= '1;
                        int_state <= state_int_idle;
                    end
                end
                state_int_mem_write: begin
                    if (!spi_mem_wif.cyc_o) begin
                        if (spi_mem_wif.ack_o) begin
                            spi_mem_wif.sel_i <= '1;
                            spi_mem_wif.addr_i <= mem_addr;
                            spi_mem_wif.dat_o <= mem_dat[15:0];
                            spi_mem_wif.stb_i <= '1;
                            spi_mem_wif.we_i <= '0;
                            int_state <= state_int_mem_write_ack;
                        end else begin
                            spi_mem_wif.sel_i <= '0;
                        end
                    end
                end
                state_int_mem_write_ack: begin
                    if (spi_mem_wif.stb_o) begin
                        spi_mem_wif.we_i <= '1;
                        spi_mem_wif.addr_i <= '0;
                        spi_mem_wif.dat_o <= '0;
                        int_state <= state_int_idle;
                    end
                end
                state_int_mem_read: begin
                    if (!spi_mem_wif.cyc_o) begin
                        if (spi_mem_wif.ack_o) begin
                            spi_mem_wif.sel_i <= '1;
                            spi_mem_wif.addr_i <= mem_addr;
                            spi_mem_wif.stb_i <= '1;
                            int_state <= state_int_mem_read_ack;
                        end else begin
                            spi_mem_wif.sel_i <= '0;
                        end
                    end
                end
                state_int_mem_read_ack: begin
                    if (spi_mem_wif.stb_o) begin
                        int_state <= state_int_mem_read_ack2;
                    end
                end
                state_int_mem_read_ack2: begin
                    if (!spi_mem_wif.cyc_o) begin
                        mem_dat[15:0] <= spi_mem_wif.dat_i;
                        spi_mem_wif.addr_i <= '0;
                        int_state <= state_int_idle;
                    end
                end
            endcase
        end
        if (spi_mem_wif.stb_i)
            spi_mem_wif.stb_i <= '0;
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

    spi_16bit_slave spi_16bit_slave_2
        (
            .phy(spi2_phy_if),
            .spi_host(spi2_host_if),

            .conf_cpol('0),
            .conf_dir('0),
            .conf_cpha('0)
        );

endmodule
