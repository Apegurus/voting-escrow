const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const { findContractFilePath } = require('./findContractFilePath'); 

const contractName = process.argv[2];

if (!contractName) {
    console.error('Error: Contract name is required.');
    process.exit(1);
}

const contractFilePath = findContractFilePath(contractName);

if (!contractFilePath) {
    console.error(`Error: Contract ${contractName} not found in the contracts directory.`);
    process.exit(1);
}

const contractPathAndName = `${contractFilePath}:${contractName}`;
const outputFileName = `storage_layout_${contractName}.json`;

exec(`forge inspect ${contractPathAndName} storage`, (error, stdout, stderr) => {
    if (error) {
        console.error(`Error executing forge inspect: ${error.message}`);
        return;
    }
    if (stderr) {
        console.error(`Error: ${stderr}`);
        return;
    }

    const outputPath = path.join(__dirname, outputFileName);
    fs.writeFileSync(outputPath, stdout);
    console.log(`Storage layout saved to ${outputFileName}`);
});