module.exports = {
  testEnvironment: 'jsdom',
  roots: ['<rootDir>/js/tests'],
  transform: {
    '^.+\\.(js|jsx)$': 'babel-jest',
  },
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/js/$1',
    '^phoenix$': '<rootDir>/__mocks__/phoenix.js'
  },
  moduleFileExtensions: ['js', 'jsx', 'json'],
  testMatch: ['**/*.test.js', '**/*.test.jsx'],
};
