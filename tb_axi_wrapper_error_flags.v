`timescale 1ns/1fs

module tb_axi_wrapper_error_flags;
    reg clk;
    reg rst;

    reg imem_req;
    reg [31:0] imem_addr;
    wire imem_ready;
    wire [31:0] imem_rdata;
    wire imem_error;

    reg dmem_req;
    reg dmem_wr;
    reg [31:0] dmem_addr;
    reg [2:0] dmem_acc_mode;
    reg [31:0] dmem_wdata;
    wire dmem_ready;
    wire [31:0] dmem_rdata;
    wire dmem_error;

    wire [31:0] M_AXI_AWADDR;
    wire M_AXI_AWVALID;
    reg  M_AXI_AWREADY;
    wire [31:0] M_AXI_WDATA;
    wire [3:0] M_AXI_WSTRB;
    wire M_AXI_WVALID;
    reg  M_AXI_WREADY;
    reg  [1:0] M_AXI_BRESP;
    reg  M_AXI_BVALID;
    wire M_AXI_BREADY;
    wire [31:0] M_AXI_ARADDR;
    wire M_AXI_ARVALID;
    reg  M_AXI_ARREADY;
    reg  [31:0] M_AXI_RDATA;
    reg  [1:0] M_AXI_RRESP;
    reg  M_AXI_RVALID;
    wire M_AXI_RREADY;

    rv32i_axi_master_wrapper dut (
        .clk(clk), .rst(rst),
        .imem_req(imem_req), .imem_addr(imem_addr),
        .imem_ready(imem_ready), .imem_rdata(imem_rdata), .imem_error(imem_error),
        .dmem_req(dmem_req), .dmem_wr(dmem_wr), .dmem_addr(dmem_addr),
        .dmem_acc_mode(dmem_acc_mode), .dmem_wdata(dmem_wdata),
        .dmem_ready(dmem_ready), .dmem_rdata(dmem_rdata), .dmem_error(dmem_error),
        .M_AXI_AWADDR(M_AXI_AWADDR), .M_AXI_AWVALID(M_AXI_AWVALID), .M_AXI_AWREADY(M_AXI_AWREADY),
        .M_AXI_WDATA(M_AXI_WDATA), .M_AXI_WSTRB(M_AXI_WSTRB), .M_AXI_WVALID(M_AXI_WVALID), .M_AXI_WREADY(M_AXI_WREADY),
        .M_AXI_BRESP(M_AXI_BRESP), .M_AXI_BVALID(M_AXI_BVALID), .M_AXI_BREADY(M_AXI_BREADY),
        .M_AXI_ARADDR(M_AXI_ARADDR), .M_AXI_ARVALID(M_AXI_ARVALID), .M_AXI_ARREADY(M_AXI_ARREADY),
        .M_AXI_RDATA(M_AXI_RDATA), .M_AXI_RRESP(M_AXI_RRESP), .M_AXI_RVALID(M_AXI_RVALID), .M_AXI_RREADY(M_AXI_RREADY)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task do_read_error;
        input is_data;
        begin
            @(negedge clk);
            imem_req = !is_data;
            dmem_req = is_data;
            dmem_wr  = 1'b0;
            M_AXI_ARREADY = 1'b0;
            M_AXI_RVALID  = 1'b0;
            wait (M_AXI_ARVALID === 1'b1);
            @(negedge clk);
            M_AXI_ARREADY = 1'b1;
            @(negedge clk);
            M_AXI_ARREADY = 1'b0;
            wait (M_AXI_RREADY === 1'b1);
            M_AXI_RDATA  = 32'hDEAD_BEEF;
            M_AXI_RRESP  = 2'b10;
            M_AXI_RVALID = 1'b1;
            @(negedge clk);
            M_AXI_RVALID = 1'b0;
            imem_req = 1'b0;
            dmem_req = 1'b0;
        end
    endtask

    task do_write_error;
        begin
            @(negedge clk);
            dmem_req = 1'b1;
            dmem_wr  = 1'b1;
            M_AXI_AWREADY = 1'b0;
            M_AXI_WREADY  = 1'b0;
            M_AXI_BVALID  = 1'b0;
            wait (M_AXI_AWVALID === 1'b1 && M_AXI_WVALID === 1'b1);
            @(negedge clk);
            M_AXI_AWREADY = 1'b1;
            M_AXI_WREADY  = 1'b1;
            @(negedge clk);
            M_AXI_AWREADY = 1'b0;
            M_AXI_WREADY  = 1'b0;
            wait (M_AXI_BREADY === 1'b1);
            M_AXI_BRESP  = 2'b10;
            M_AXI_BVALID = 1'b1;
            @(negedge clk);
            M_AXI_BVALID = 1'b0;
            dmem_req = 1'b0;
            dmem_wr  = 1'b0;
        end
    endtask

    initial begin
        rst = 1'b1;
        imem_req = 1'b0;
        imem_addr = 32'b0;
        dmem_req = 1'b0;
        dmem_wr = 1'b0;
        dmem_addr = 32'h1000_0000;
        dmem_acc_mode = 3'b010;
        dmem_wdata = 32'h1234_5678;
        M_AXI_AWREADY = 1'b0;
        M_AXI_WREADY = 1'b0;
        M_AXI_BRESP = 2'b00;
        M_AXI_BVALID = 1'b0;
        M_AXI_ARREADY = 1'b0;
        M_AXI_RDATA = 32'b0;
        M_AXI_RRESP = 2'b00;
        M_AXI_RVALID = 1'b0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        fork
            do_read_error(1'b0);
            begin
                wait (imem_ready === 1'b1);
                if (imem_error !== 1'b1) begin
                    $display("[TB][FAIL] imem_error not asserted on RRESP error");
                    $finish;
                end
            end
        join

        repeat (3) @(posedge clk);

        fork
            do_read_error(1'b1);
            begin
                wait (dmem_ready === 1'b1);
                if (dmem_error !== 1'b1) begin
                    $display("[TB][FAIL] dmem_error not asserted on RRESP error");
                    $finish;
                end
            end
        join

        repeat (3) @(posedge clk);

        fork
            do_write_error;
            begin
                wait (dmem_ready === 1'b1);
                if (dmem_error !== 1'b1) begin
                    $display("[TB][FAIL] dmem_error not asserted on BRESP error");
                    $finish;
                end
            end
        join

        $display("[TB][PASS] AXI RRESP/BRESP error flags PASS");
        $finish;
    end
endmodule
