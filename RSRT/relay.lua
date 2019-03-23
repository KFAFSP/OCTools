--[[ RSRT RELAY

Summary:
	Reference implementation of a dedicated RSRT relay.

Remarks:
	The program must be flashed onto an EEPROM. The data field of the EEPROM must be a valid
	configuration string.

	Some configuration is fixed, including the redstone side setup. The RX bundle must be connected
	to the right side of the block, while the TX bundle needs to connect to the left. Optionally,
	the bottom side will output the busy state: busy on "white", and sending on "orange".

	Configuration is supplied as a NULL("\0") delimited list (final terminator necessary):
	"TRUST\0PORT\0CHANNELS\0PRIORITY\0TIMEOUT\0"

		TRUST 			is the (prefix of) the trusted address in the connected OC network that is
						allowed	to send messages through this relay. If it is empty, all addresses
						match and are allowed to relay messages.
		PORT[0..65535]  is the port on which the relay will send and listen.
		CHANNELS[1..6]  is the number of channels to use, starting with "white".
		PRIORITY[0..7]  is the sender priority.
		TIMEOUT[1..inf] is the receive timeout.

	The network-based protocol is defined as follows:

		<= ("RELAY", <message>) ... Relay request

			A relay request is only accepted if the sender address is matched by the TRUST prefix.
			All accepted relay requests are handled, with a maximum delay of 4.9s (yield_timeout),
			generating the following response(s):

			=> ("EINVAL") ... Invalid message

				The message argument is not a string or longer than 255 Bytes.

			=> ("EBUSY") ... Device busy

				The wire is currently busy.

			=> ("ACK") ... Acknowledged

				The device has acquired the wire and began sending the message.

					=> ("OK") ... Completed

						The device has completed sending the message.

		=> ("RELAY", <message>) ... Relayed message

			Broadcasts a received telegram to the network.

Version:
	2.0.1

--]]

--#BEGIN ROM
local l0,l1,l2=string.char,function(s,p)return s:sub(1,#p)==p end,tonumber
local a0,a1,a2,a3=computer.pullSignal,computer.uptime,component.list,component.proxy
local d0,d1,dA=a3(a2("red")()),a3(a2("mod")())
local cfg,n={},1 for x in a3(a2("eep")()).getData():gmatch("([^\0]*)\0")do cfg[n],n=x,n+1 end
local cA,cB,rE,rB,rA=cfg[1],l2(cfg[2]),l2(cfg[3]),l2(cfg[4]),l2(cfg[5])
local b0,b1,b2,b3
local ba,bb=function(c)local x=0 while c>0 do if b2==0then b1,b2,b3=b1+1,7,b1<#b0 and b0:byte(b1+1)or 0 else b2=b2-1 end x,c=x<<1|b3>>b2&1,c-1 end return x end,function(x,c)c=c-1while c>=0 do b3,b2,c=b3<<1|x>>c&1,b2+1,c-1if b2==8then b0[b1+1],b1,b2,b3=l0(b3),b1+1,0,0 end end end
local ra,rb,r0,r1,rF=function(x)return x*17 end,function(x)return math.ceil(x/17)end,{[0]=0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},{[0]=0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
local rc,rd=function()local t,i,c=d0.getBundledInput(4)r0[0]=0 for i=rE,1,-1 do t[i-1]=rb(t[i-1])r0[0],r0[i],c=r0[0]|t[i-1],t[i-1],c or r0[i]~=t[i-1]end return c end,function(x)local i for i=1,rE do r1[i-1]=ra(x[i]or 0)end d0.setBundledOutput(5,r1)end
local re,rf,rg=function()local t,s=a1(),{a0(rA)}while true do if#s==0or a1()-t>rA then return nil end if l1(s[1],"red")and s[3]==4 and s[6]<rE then if rc()then return true end else dA(s)end s={a0(rA)}end end,function()local d,i={}rc()if r0[0]~=0then rF(1,0)return nil end d[1]=8|rB for i=2,rE do d[i]=0 end rF(1,1)rd(d)rc()if r0[1]~=d[1]then rF(1,0)rd({})return nil end return true end,function(s)b0,b1,b2,b3=l0(#s)..s,0,0,0local d,x,c,t,i,s={},0,0,a1()while b1<#b0 do x,d[1]=0,c|ba(3)for i=2,rE do d[i]=ba(4)x=x|d[i]end if x|d[1]==0then for i=1,rE do d[i]=rb(r1[i-1])end d[1]=d[1]~1 else c=c~8 end rd(d)if a1()-t>=4.8then t,s=a1(),{a0(0)}while#s>0 do dA(s)s={a0(0)}end end end rd({})rF(0,0)rc()end
local rh=function()b0,b1,b2,b3={},0,0,0local c,i=0while true do if not re()then return nil end if r0[0]==0then break end if c~=r0[1]&8then bb(0,rE*4-1)else c=c~8 bb(r0[1]&7,3)for i=2,rE do bb(r0[i],4)end end end bb(0,8-b2)rF(0,0)b0=table.concat(b0)return#b0>b0:byte(1)and b0:sub(2,1+b0:byte(1))end
local s0=0
rF,dA=function(b,s)s0=b d0.setBundledOutput(0,{[0]=b*255,s*255})end,function(s)if l1(s[1],"mod")and cB==s[4]and l1(s[3],cA)then d1.send(s[3],cB,"EBUSY")end end
rd({})rF(0,0)d1.open(cB)d1.broadcast(cB,"ANNOUNCE")
while true do
	local s,x={a0()}
	if l1(s[1],"red")and 4==s[3]and rE>s[6]and rc()then
		rF(1,0)
		if r0[1]&8>0 then x=rh()if x then d1.broadcast(cB,"RELAY",x) end end
		if s0 then rc()while true do if r0[0]==0then rF(0,0)break end re()end end
	elseif l1(s[1],"mod")and cB==s[4]and l1(s[3],cA)and s[6]=="RELAY"then
		x=s[7]
		if type(x)=="string"and#x<255then
			if rf() then d1.send(s[3],cB,"ACK")rg(x)x="OK"else x="EBUSY"end
		else x="EINVAL"end
		d1.send(s[3],cB,x)
	end
end