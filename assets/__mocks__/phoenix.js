// Mock for phoenix module
const Socket = jest.fn().mockImplementation(() => {
  return {
    channel: jest.fn().mockReturnValue({
      join: jest.fn().mockReturnValue({
        receive: jest.fn().mockReturnValue({
          receive: jest.fn().mockReturnValue({})
        })
      }),
      on: jest.fn(),
      leave: jest.fn(),
      push: jest.fn().mockReturnValue({
        receive: jest.fn()
      })
    }),
    connect: jest.fn()
  };
});

export { Socket };