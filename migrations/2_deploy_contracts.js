var TraceApplication = artifacts.require("./TraceApplication.sol");

module.exports = function(deployer) {
  deployer.deploy(TraceApplication);
};
