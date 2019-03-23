--[[ HEADLESS RSRT DRIVER

Summary:
    The headless RSRT driver implements the minimum required functionality to transmit and receive
    data on an RSRT bus.

Remarks:
    * On any top-level declaration, the "local" keyword can be removed, degrading performance but
    decreasing code size.
    * All two-letter symbols are only defined once and can therefore be renamed using find and
    replace, if necessary.

Version:
    2.0.1

]]

-- =======
-- ALIASES
-- =======
--[[
    These aliases are required by the driver below. They are used so frequently, that it is worth
    turning them into local symbols.

    string_filter implements the default filtering algorithm of matching a string against a prefix.
--]]

-- l0, l1 = string.char, string_filter
local l0,l1=string.char,function(s,p)return s:sub(1,#p)==p end
local a0,a1,a2,a3=computer.pullSignal,computer.uptime,component.list,component.proxy

-- =======
-- DEVICES
-- =======
--[[
    These symbols must point to proxies of the devices required by the driver.

    dA(event: table) is the deffered event handler, which is called whenever an event is pulled that
    shall not be handled now. It should either push the event to another queue, or give a negative
    acknowledgment, whatever is more appropriate for the use case.
--]]

-- d0, d1 = redstone, modem
-- dA = deffered_event_handler
local d0,d1=a3(a2("red")()),a3(a2("mod")())
local dA=function()end

-- ===========
-- BIT STREAMS
-- ===========
--[[
    The following symbols implement a bit reader and writer adapter for byte streams. They share a
    global state that must be initialized prior depending on whether reading or writing shall take
    place.

Reading:
    b0 is a string of bytes to read.
    b1 is the current read offset (usually starts at 0).
    b2 is the current remaining bit count (usually starts at 0).
    b3 is the current byte (usually starts at 0).

    ba(count: int) will read the next count bits into an integer. If more bits are requested than
    are available, the result will be zero-padded.

Writing:
    b0 is a table of written bytes a string with length 1.
    b1 is the current write offset (usually starts at 0).
    b2 is the current bit count (usually starts at 0).
    b3 is the current byte (usually starts at 0).

    bb(x: int, count: int) will write count bits from x, starting from msb.

    It is advisable to flush after writing all bits, using bb(0,8-b2). This will pad with zeroes.
    After that, the written byte string can be obtained using table.concat(b0).
--]]

-- b0, b1, b2, b3 = <read: string; write: array>, offset, bits, current
-- ba, bb = bit_read(count), bit_write(x, count)
local b0,b1,b2,b3
local ba,bb=function(c)local x=0 while c>0 do if b2==0then b1,b2,b3=b1+1,7,b1<#b0 and b0:byte(b1+1)or 0 else b2=b2-1 end x,c=x<<1|b3>>b2&1,c-1 end return x end,function(x,c)c=c-1while c>=0 do b3,b2,c=b3<<1|x>>c&1,b2+1,c-1if b2==8then b0[b1+1],b1,b2,b3=l0(b3),b1+1,0,0 end end end

-- ===========
-- RSRT DRIVER
-- ===========
--[[
    The following symbols implement the actual headless RSRT driver. All of the symbols above are
    required dependencies of this code. Symbols ending in capital letters are configuration vars
    that either need to be initialized at runtime, or can be statically replaced with their actual
    values when packaging the driver.

    rF(busy: int, sending: int) is the busy handler. Whenever the busy state changes, that means
    driver code detected or will cause a busy wire, it indicates 1, otherwise 0. The sending bit
    indicates whether the driver is curently sending.

        The state is not set or reset if the driver is not called!

Receiving:
    The external code can await the start of a transmission by waiting for a redstone event to
    happen that turns the most significant bit of the first RX channel on. Immediately after, it may
    call rh() to receive the data. The result will be the received message, or nil on error. If
    the busy state is still set after this call, a timeout occured. Events during receive will be
    delegated to the dA handler.

Sending:
    rf() must be called to announce the transmission start on the wire. If nil is returned, the wire
    is busy. Otherwise the wire was acquired and the transmission must start.

    rg(message: string) does the transmission after rf() returned non-nil. It returns after the end
    of the transmission, and will delegate events to the dA handler if yield timeout prevention
    occurs.
--]]

-- ra, rb, rc, rd, re, rf, rg, rh = upscale, downscale, read, write, yield, begin_tx, tx, rx
-- r0, r1 = in_buffer, out_buffer
-- rA, rB, rC, rD, rE, rF = timeout, priority, rx_side, tx_side, channels, busy_handler
local ra,rb,r0,r1,rA,rB,rC,rD,rE,rF=function(x)return x*17 end,function(x)return math.ceil(x/17)end,{[0]=0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{[0]=0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
local rc,rd=function()local t,i,c=d0.getBundledInput(rC)r0[0]=0 for i=rE,1,-1 do t[i-1]=rb(t[i-1])r0[0],r0[i],c=r0[0]|t[i-1],t[i-1],c or r0[i]~=t[i-1]end return c end,function(x)local i for i=1,rE do r1[i-1]=ra(x[i]or 0)end d0.setBundledOutput(rD,r1)end
local re,rf,rg=function()local t,s=a1(),{a0(rA)}while true do if#s==0or a1()-t>rA then return nil end if l1(s[1],"red")and s[3]==rC and s[6]<rE then if rc()then return true end else dA(s)end s={a0(rA)}end end,function()local d,i={}rc()if r0[0]~=0then rF(1,0)return nil end d[1]=8|rB for i=2,rE do d[i]=0 end rF(1,1)rd(d)rc()if r0[1]~=d[1]then rF(1,0)rd({})return nil end return true end,function(s)b0,b1,b2,b3=l0(#s)..s,0,0,0local d,x,c,t,i,s={},0,0,a1()while b1<#b0 do x,d[1]=0,c|ba(3)for i=2,rE do d[i]=ba(4)x=x|d[i]end if x|d[1]==0then for i=1,rE do d[i]=rb(r1[i-1])end d[1]=d[1]~1 else c=c~8 end rd(d)if a1()-t>=4.8then t,s=a1(),{a0(0)}while#s>0 do dA(s)s={a0(0)}end end end rd({})rF(0,0)rc()end
local rh=function()b0,b1,b2,b3={},0,0,0local c,i=0while true do if not re()then return nil end if r0[0]==0then break end if c~=r0[1]&8then bb(0,rE*4-1)else c=c~8 bb(r0[1]&7,3)for i=2,rE do bb(r0[i],4)end end end bb(0,8-b2)rF(0,0)b0=table.concat(b0)return#b0>b0:byte(1)and b0:sub(2,1+b0:byte(1))end