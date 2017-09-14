pragma solidity ^0.4.4;
import 'Common.sol';

contract TraceData{
    address                         public  owner;
    mapping(bytes16 => UcodeDetail)  public  nthUcodeMap;

    struct UcodeDetail{
        uint8       status;
        bytes31     extinfo;
        address     preuserid;
    }

    modifier onlyOwner() {
        if (msg.sender == owner) _;
    }
    
    ////////////////////////////////////////////////////////
    // description: data writer, just write, donot check 
    ////////////////////////////////////////////////////////
    function setter(bytes16 nthucode, uint8 status, bytes31 extinfo, address preuserid) onlyOwner returns(uint8){
        require(status != 0);

        UcodeDetail storage ud  = nthUcodeMap[nthucode];
        ud.status               = status;
        if (extinfo != 0){
            ud.extinfo          = extinfo;
        }
        if (preuserid != 0){
            ud.preuserid        = preuserid;
        }

        return ud.status;
    }

}
