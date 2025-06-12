
# Containerized Job Queue

Some tasks, primarily autograding, require spinning up a container
that needs reliable resources.

To avoid excess concurrent resource usage, we want to have a job queue.

Shared Resources:

- Cores (Can be fractional)
- RAM (Megs)
- Time Limit (Seconds)

## Grading Flow

### Creating an Assignment

- Prof creates assignment.
- Uploads starter code and solution.
- Creates "script" grading column with grading script;
  resource limits are set here.
- Can have multiple script columns with separate resource limits.

### Script Column Properties

- Resource usages.

### Submitting an Assignment

- Student submits assignment, including file upload.
- The submission gets added to the queue.
- Wait in queue.

### 

- autograde! gets run for each script column

## Autograder Examples

- Test script (in container)
- Style Checker
- LLM+Rubric (not in container)
