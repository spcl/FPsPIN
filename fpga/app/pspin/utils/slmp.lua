local proto_slmp = Proto.new("slmp", "sPIN Lightweight Messaging Protocol")

local eom_mask = 0x8000
local syn_mask = 0x4000
local ack_mask = 0x2000
local reserved_mask = bit32.band(0xffff, bit32.bnot(bit32.bor(eom_mask, syn_mask, ack_mask)))

local field_flags = ProtoField.uint16("slmp.flags", "Flags", base.HEX)
local field_flags_eom = ProtoField.uint16("slmp.eom", "End of Message", base.DEC, NULL, eom_mask)
local field_flags_syn = ProtoField.uint16("slmp.syn", "Synchronisation", base.DEC, NULL, syn_mask)
local field_flags_ack = ProtoField.uint16("slmp.ack", "Acknowledgement", base.DEC, NULL, ack_mask)
local field_flags_reserved = ProtoField.uint16("slmp.reserved", "Reserved", base.HEX, NULL, reserved_mask)
local field_msgid = ProtoField.uint32("slmp.msgid", "Message ID", base.DEC)
local field_offset = ProtoField.uint32("slmp.offset", "Packet Offset", base.DEC)
local field_payload = ProtoField.bytes("slmp.payload", "Payload")

proto_slmp.fields = { field_flags, field_flags_eom, field_flags_syn, field_flags_ack, field_flags_reserved,
    field_msgid, field_offset, field_payload }

function proto_slmp.dissector(buffer, pinfo, tree)
    pinfo.cols.protocol = "SLMP"

    local subtree = tree:add(proto_slmp, buffer())

    local flags_pos = 0
    local flags_len = 2
    local flags_buffer = buffer(flags_pos, flags_len)

    local flags_tree = subtree:add(field_flags, flags_buffer)
    flags_tree:add(field_flags_eom, flags_buffer)
    flags_tree:add(field_flags_syn, flags_buffer)
    flags_tree:add(field_flags_ack, flags_buffer)
    flags_tree:add(field_flags_reserved, flags_buffer)

    local msgid_pos = flags_pos + flags_len
    local msgid_len = 4
    local msgid_buffer = buffer(msgid_pos, msgid_len)
    subtree:add(field_msgid, msgid_buffer)

    local offset_pos = msgid_pos + msgid_len
    local offset_len = 4
    local offset_buffer = buffer(offset_pos, offset_len)
    subtree:add(field_offset, offset_buffer)

    local payload_pos = offset_pos + offset_len
    local payload_len = buffer:len() - 10
    local payload_buffer = buffer(payload_pos, payload_len)
    subtree:add(field_payload, payload_buffer)

    local flags_str = ""
    local flags = flags_buffer:uint()
    if (bit32.band(flags, eom_mask) ~= 0) then
        flags_str = flags_str .. "E"
    end
    if (bit32.band(flags, syn_mask) ~= 0) then
        flags_str = flags_str .. "S"
    end
    if (bit32.band(flags, ack_mask) ~= 0) then
        flags_str = flags_str .. "A"
    end
    if (flags_str ~= "") then
        flags_str = "[" .. flags_str .. "]"
    end
    local desc = flags_str .. " MsgId=" .. msgid_buffer:uint() ..
        " Off=" .. offset_buffer:uint() .. " Len=" .. payload_len
    
    pinfo.cols.info = desc
end

DissectorTable.get("udp.port"):add(9330, proto_slmp)
