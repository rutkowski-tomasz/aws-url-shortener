module.exports = {
    projects: [
      "<rootDir>/src/*",
    ],
    collectCoverageFrom: [
      "**/*.{ts,tsx,js,jsx}",  // Include both TypeScript and JavaScript
      "!**/node_modules/**",   // Exclude node_modules
      "!**/dist/**",           // Exclude built files
      "!**/__pycache__/**",    // Exclude Python cache files
      "!**/*.py"               // Exclude Python files
    ],
    collectCoverage: true,
    coverageDirectory: "<rootDir>/.coverage",
    testPathIgnorePatterns: ["/node_modules/", "/dist/", "/__pycache__/"],
    coveragePathIgnorePatterns: ["/node_modules/", "/dist/"],
    preset: 'ts-jest',
    testEnvironment: 'node',
    transform: {
      '^.+\\.ts$': 'ts-jest',    // Use ts-jest for TypeScript files
      '^.+\\.js$': 'babel-jest'  // Use Babel for JavaScript files (optional, you can adjust as needed)
    },
    roots: ['<rootDir>/src']
};
