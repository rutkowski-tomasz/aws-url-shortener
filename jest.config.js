module.exports = {
    projects: [
      "<rootDir>/src/*",
    ],
    collectCoverageFrom: [
      "**/*.{ts,tsx,js,jsx}",
      "!**/node_modules/**",
      "!**/dist/**",
      "!**/__pycache__/**",
      "!**/*.py"
    ],
    collectCoverage: true,
    coverageDirectory: "<rootDir>/.coverage",
    testPathIgnorePatterns: ["/node_modules/", "/dist/", "/__pycache__/"],
    coveragePathIgnorePatterns: ["/node_modules/", "/dist/"],
    preset: 'ts-jest',
    testEnvironment: 'node',
    transform: {
      '^.+\\.ts$': 'ts-jest',
      '^.+\\.js$': 'babel-jest'
    },
    roots: ['<rootDir>/src'],
    globals: {
      'ts-jest': {
          tsconfig: 'tsconfig.json',
          diagnostics: false,
      },
  },
};
