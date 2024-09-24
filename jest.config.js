module.exports = {
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
    silent: true,
    transform: {
      '^.+\\.ts$': ['ts-jest', { tsconfig: 'tsconfig.json', diagnostics: false }],
      '^.+\\.js$': 'babel-jest'
    },
    reporters: [
      'default',
      'summary',
      ['github-actions', {silent: false}],
    ],
    roots: ['<rootDir>/src'],
};
