pragma solidity ^0.4.4;
import "./TraceData.sol";

contract TraceApplication{
    address                         private admin;

    mapping(address => address)     private userDataMap;
    mapping(bytes16 => UcodeInfo)   private ucodeInfoMap;
    mapping(bytes16 => UcodeTmpInf) private ucodeTmpInfoMap;

    struct UcodeInfo{
        uint8                       nth;
        address                     owner; 
    }

    struct UcodeTmpInf{
        uint                        pendingtime;
        address                     nextowner;
    }

    enum UcodeStatus{ 
        INVALIDE,                   //= 0,
        START_TRANSFER_IN,          //= 1,
        TRANSFER_IN_SUCCESS,        //= 2,
        START_TRANSFER_OUT,         //= 3,
        TRANSFER_OUT_SUCCESS,       //= 4,
        FORBIDDEN                   //= 5
    }

    event AccountRegister(
            address indexed         account,
            bool                    result
            );

    event UcodeRegister(
            address indexed         owner,
            bytes16 indexed         ucode,
            bool                    result
            );
    
    event UcodeTransfer(
            address indexed         owner,
            address indexed         toaccount,
            bytes16 indexed         ucode,
            bool                    result
            );
    
    event UcodeAccept(
            address indexed         owner,
            address indexed         toaccount,
            bytes16 indexed         ucode,
            bool                    result
            );

    event UcodeTransferWithoutAccept(
            address indexed         owner,
            address indexed         toaccount,
            bytes16 indexed         ucode,
            bool                    result
            );

    modifier onlyOwner() {
        if (msg.sender == admin) _;
    }

    modifier onlyUser() {
        if (userDataMap[msg.sender] != 0) _;
    }


    ////////////////////////////////////////////////////////
    // description: constructor, set the admin to sender 
    ////////////////////////////////////////////////////////
    function TraceApplication() {
        admin = msg.sender;
    }

    ////////////////////////////////////////////////////////
    // description: concat 'nth' and 'ucode' to bytes16,
    //              can only call internal.
    ////////////////////////////////////////////////////////
    function _getNthUcode(uint8 nth, bytes16 ucode) internal returns(bytes16){
        return (ucode & 0x00ffffffffffffffffffffffffffffff) | bytes16(nth);
    }


    ////////////////////////////////////////////////////////
    // description: register account, can only call by YQTC
    ////////////////////////////////////////////////////////
    function registerAccount(address account) onlyOwner{
        if (userDataMap[account] == 0){
            TraceData td = new TraceData();
            userDataMap[account] = td;
            AccountRegister(account, true);
        }else{
            AccountRegister(account, false);
        }
    }

    ////////////////////////////////////////////////////////
    // description: register ucode
    ////////////////////////////////////////////////////////
    function registerUcode(bytes16 ucode) onlyUser{
        UcodeInfo storage ucodeinfo = ucodeInfoMap[ucode];
        if (ucodeinfo.nth == 0){
            ucodeinfo.nth       = 1; 
            ucodeinfo.owner     = msg.sender; 
            TraceData td        = TraceData(userDataMap[msg.sender]);

            var nthucode        = _getNthUcode(ucodeinfo.nth, ucode);
            td.setter(nthucode, uint8(UcodeStatus.TRANSFER_IN_SUCCESS), 0, 0);

            // register success.
            UcodeRegister(msg.sender, ucode, true);
        }else{
            // have been registered.
            UcodeRegister(msg.sender, ucode, false);
        }
    }

    ////////////////////////////////////////////////////////
    // description: transfer ucode to other
    ////////////////////////////////////////////////////////
    function transferUcodeWithoutAccept(bytes16 ucode, address toaccount) onlyUser{
        UcodeInfo storage ucodeinfo = ucodeInfoMap[ucode];

        require(ucodeinfo.nth != 0 
                && ucodeinfo.owner == msg.sender
                && userDataMap[msg.sender] != 0 
                && toaccount != msg.sender);

        TraceData srctd     = TraceData(userDataMap[msg.sender]);
        TraceData desttd    = TraceData(userDataMap[toaccount]);


        var nthucode1       = _getNthUcode(ucodeinfo.nth, ucode);            
        srctd.setter(nthucode1, uint8(UcodeStatus.TRANSFER_OUT_SUCCESS), 0, 0);
        
        var nthucode2       = _getNthUcode(ucodeinfo.nth + 1, ucode);            
        desttd.setter(nthucode2, uint8(UcodeStatus.TRANSFER_IN_SUCCESS), 0, msg.sender);

        ucodeinfo.nth       = ucodeinfo.nth + 1;
        ucodeinfo.owner     = toaccount;

        UcodeTransferWithoutAccept(msg.sender, toaccount, ucode, true);
    }

    ////////////////////////////////////////////////////////
    // description: transfer ucode to other
    ////////////////////////////////////////////////////////
    function transferUcode(bytes16 ucode, address toaccount) onlyUser{
        UcodeInfo storage ucodeinfo = ucodeInfoMap[ucode];
        TraceData srctd     = TraceData(userDataMap[msg.sender]);
        TraceData desttd    = TraceData(userDataMap[toaccount]);

        require(ucodeinfo.nth != 0
                && ucodeinfo.owner == msg.sender
                && userDataMap[msg.sender] != 0
                && toaccount != msg.sender);

        var nthucode1       = _getNthUcode(ucodeinfo.nth, ucode);
        var (status, x, y)  =srctd.nthUcodeMap(nthucode1);
        require(status == uint8(UcodeStatus.TRANSFER_IN_SUCCESS)
                ||  (status == uint8(UcodeStatus.START_TRANSFER_OUT)
                    && ucodeTmpInfoMap[ucode].pendingtime  < now
                    ));

        srctd.setter(nthucode1, uint8(UcodeStatus.START_TRANSFER_OUT), 0, 0);
        ucodeTmpInfoMap[ucode].pendingtime  = now + 86400;
        ucodeTmpInfoMap[ucode].nextowner    = toaccount;
        UcodeTransfer(msg.sender, toaccount, ucode, true);
    }

    ////////////////////////////////////////////////////////
    // description: accept ucode
    ////////////////////////////////////////////////////////
    function acceptUcode(bytes16 ucode, address toaccount) onlyUser{
        UcodeInfo storage ucodeinfo = ucodeInfoMap[ucode];
        TraceData srctd = TraceData(userDataMap[msg.sender]);
        TraceData desttd = TraceData(userDataMap[toaccount]);

        require(ucodeinfo.nth != 0 
                && ucodeinfo.owner == msg.sender
                && userDataMap[msg.sender] != 0 
                && toaccount != msg.sender
                && ucodeTmpInfoMap[ucode].nextowner == msg.sender);

        var nthucode1       = _getNthUcode(ucodeinfo.nth, ucode);
        var (status, x, y)  = srctd.nthUcodeMap(nthucode1);
        require(status == uint8(UcodeStatus.START_TRANSFER_OUT));
        srctd.setter(nthucode1, uint8(UcodeStatus.TRANSFER_OUT_SUCCESS), 0, 0);

        var nthucode2       = _getNthUcode(ucodeinfo.nth + 1, ucode);
        desttd.setter(nthucode2, uint8(UcodeStatus.TRANSFER_IN_SUCCESS), 0, msg.sender);

        delete ucodeTmpInfoMap[ucode];

        UcodeTransfer(msg.sender, toaccount, ucode, true);
    }

    ////////////////////////////////////////////////////////
    // description: checkout ucode
    ////////////////////////////////////////////////////////
    function checkOut(bytes16 ucode) constant returns(uint16 nth, address owner){
        UcodeInfo storage ucodeinfo = ucodeInfoMap[ucode];
        return (ucodeinfo.nth, ucodeinfo.owner);
    }

    ////////////////////////////////////////////////////////
    //function forward(uint value, bytes data) {
    //    address destination = userDataMap[msg.sender];
    //    if (destination != 0){
    //        Forwarded(msg.sender, value, data);
    //        destination.call.value(value)(data)) {
    //    }
    //}
    ////////////////////////////////////////////////////////
}
