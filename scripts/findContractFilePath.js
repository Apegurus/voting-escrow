const fs = require('fs');
const path = require('path');

const contractsDir = path.join(__dirname, '../contracts');

// Function to recursively search for the contract file
function findContractFilePath(contractName) {
    function searchDirectory(dir) {
        console.log(`Searching in directory: ${dir}`);
        const files = fs.readdirSync(dir);

        for (const file of files) {
            const fullPath = path.join(dir, file);
            const stat = fs.statSync(fullPath);

            if (stat.isDirectory()) {
                const result = searchDirectory(fullPath);
                if (result) {
                    return result;
                }
            } else if (stat.isFile() && file.endsWith('.sol')) {
                const content = fs.readFileSync(fullPath, 'utf8');
                const regex = new RegExp(`\\bcontract\\s+${contractName}\\b`);
                if (regex.test(content)) {
                    return fullPath;
                }
            }
        }

        return null;
    }

    return searchDirectory(contractsDir);
}

module.exports = { findContractFilePath };