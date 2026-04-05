# Inkfish API v1

**Base URL**: `https://inkfish.homework.quest/api/v1`  
**Auth**: `x-auth: YOUR_API_KEY` header  
**Content-Type**: `application/json` (except file uploads)

## Endpoints

### Student

| Method | Endpoint | Params |
|--------|----------|--------|
| GET | `/api/v1/subs` | `assignment_id`, `page` |
| GET | `/api/v1/subs/:id` | |
| POST | `/api/v1/subs` | `sub[upload]`, `sub[assignment_id]`, `sub[hours_spent]` (multipart) |

### Staff

| Method | Endpoint | Params |
|--------|----------|--------|
| GET | `/api/v1/staff/dashboard` | |
| GET | `/api/v1/staff/courses/:id` | |
| GET | `/api/v1/staff/courses/:id/gradesheet` | |
| POST | `/api/v1/staff/courses/:course_id/teamsets` | `teamset{name,size}` |
| POST | `/api/v1/staff/assignments` | `assignment{name,bucket_id,due,desc}` |
| GET | `/api/v1/staff/assignments/:id` | |
| POST | `/api/v1/staff/assignments/:id/recalc_grades` | |
| GET | `/api/v1/staff/subs` | `assignment_id`, `page` |
| GET | `/api/v1/staff/subs/:id` | |
| GET | `/api/v1/staff/grades` | `sub_id` |
| GET | `/api/v1/staff/grades/:id` | |
| POST | `/api/v1/staff/grades` | `sub_id`, `grade{grade_column_id, score \| line_comments}` |

## curl Examples with Responses

```bash
# List submissions
curl -H "x-auth: KEY" "http://localhost:4000/api/v1/subs?assignment_id=22"
# Returns: {"data":[{"id":"1","active":true,"score":85.5,"upload":"/uploads/uuid/file.zip","team":{"id":1,"teamset_id":2,"active":true,"members":[{"id":1,"user_id":3,"name":"Alice Smith"},{"id":2,"user_id":4,"name":"Bob Jones"}]}}]}

# Upload submission
curl -X POST -H "x-auth: KEY" \
  -F "sub[upload]=@file.zip" -F "sub[assignment_id]=22" \
  "http://localhost:4000/api/v1/subs"
# Returns: {"data":{"id":"1","active":true,"score":null,"team":{"id":1,"teamset_id":2,"active":true,"members":[{"id":1,"user_id":3,"name":"Alice Smith"}]}}}

# Staff dashboard
curl -H "x-auth: KEY" "http://localhost:4000/api/v1/staff/dashboard"
# Returns: {"courses":[{"id":1,"name":"CS101","past_assignments_with_ungraded":[...],"upcoming_by_bucket":{}}]}

# Course details
curl -H "x-auth: KEY" "http://localhost:4000/api/v1/staff/courses/1"
# Returns: {"data":{"id":"1","name":"CS101","buckets":[...],"teamsets":[...],"assignments":[...]}}

# Course gradesheet
curl -H "x-auth: KEY" "http://localhost:4000/api/v1/staff/courses/1/gradesheet"
# Returns: {"data":{"course":{"id":"1","name":"CS101"},"buckets":[...],"students":[{"reg":{"id":"1","user":{...}},"grades":{}}]}}

# Create assignment
curl -X POST -H "x-auth: KEY" -H "Content-Type: application/json" \
  -d '{"assignment":{"name":"HW1","bucket_id":"1","due":"2026-03-01T23:59:59Z"}}' \
  "http://localhost:4000/api/v1/staff/assignments"
# Returns: {"data":{"id":"1","name":"HW1","due":"2026-03-01T23:59:59Z","bucket":{"id":"1","name":"Homework"}}}

# Get assignment
curl -H "x-auth: KEY" "http://localhost:4000/api/v1/staff/assignments/1"
# Returns: {"data":{"id":"1","name":"HW1","due":"...","bucket":{...},"grade_columns":[...],"subs":[]}}

# Recalculate grades
curl -X POST -H "x-auth: KEY" "http://localhost:4000/api/v1/staff/assignments/1/recalc_grades"
# Returns: 204 No Content

# List submissions (staff)
curl -H "x-auth: KEY" "http://localhost:4000/api/v1/staff/subs?assignment_id=22"
# Returns: {"data":[{"id":"1","active":true,"score":85.5,"reg":{"id":"1","user":{"email":"..."}},"team":{"id":1,"teamset_id":2,"active":true,"members":[{"id":1,"user_id":3,"name":"Alice Smith"},{"id":2,"user_id":4,"name":"Bob Jones"}]}}]}

# Get submission (staff)
curl -H "x-auth: KEY" "http://localhost:4000/api/v1/staff/subs/1"
# Returns: {"data":{"id":"1","active":true,"score":85.5,"reg":{...},"upload":"/uploads/...","team":{"id":1,"teamset_id":2,"active":true,"members":[{"id":1,"user_id":3,"name":"Alice Smith"},{"id":2,"user_id":4,"name":"Bob Jones"}]}}}

# List grades
curl -H "x-auth: KEY" "http://localhost:4000/api/v1/staff/grades?sub_id=1"
# Returns: {"data":[{"id":"1","score":"85.5","grade_column_id":3,"grade_column":{...},"line_comments":[{"path":"main.c","line":10,"points":"-5.0","text":"Style issue"}]}]}

# Get grade
curl -H "x-auth: KEY" "http://localhost:4000/api/v1/staff/grades/1"
# Returns: {"data":{"id":"1","score":"85.5","grade_column_id":3,"grade_column":{...},"log_uuid":"uuid","line_comments":[{"path":"main.c","line":10,"points":"-5.0","text":"Style issue",...}]}}

# Create number grade (for grade columns of type "number")
# Note: Number grades require a score value
curl -X POST -H "x-auth: KEY" -H "Content-Type: application/json" \
  -d '{"grade":{"grade_column_id":"5","score":"8.5"}}' \
  "http://localhost:4000/api/v1/staff/grades?sub_id=1"
# Returns: {"data":{"id":"2","score":"8.5","grade_column_id":5,"grade_column":{...},"line_comments":[]}}

# Create feedback grade (for grade columns of type "feedback")
# Note: Score is calculated automatically from line_comments
curl -X POST -H "x-auth: KEY" -H "Content-Type: application/json" \
  -d '{"grade":{"grade_column_id":"3","line_comments":[{"path":"main.c","line":10,"points":"-5.0","text":"Style issue"},{"path":"main.c","line":15,"points":"-3.0","text":"Logic error"}]}}' \
  "http://localhost:4000/api/v1/staff/grades?sub_id=1"
# Returns: {"data":{"id":"3","score":"32.0","grade_column_id":3,"grade_column":{...},"line_comments":[{"path":"main.c","line":10,"points":"-5.0","text":"Style issue",...}]}}

# Create teamset
curl -X POST -H "x-auth: KEY" -H "Content-Type: application/json" \
  -d '{"teamset":{"name":"Teams","size":3}}' \
  "http://localhost:4000/api/v1/staff/courses/1/teamsets"
# Returns: {"data":{"id":"1","name":"Teams","size":3,"teams":[]}}
```

## Responses

Success: `{"data": {...}}`  
Error: `{"errors": {"field": ["message"]}}`

Status codes: 200, 201, 204, 400, 403, 404, 422

## Response Fields

### Sub

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Submission ID |
| active | boolean | Whether submission is active |
| late_penalty | decimal \| null | Late penalty applied |
| score | decimal \| null | Final score |
| hours_spent | decimal | Hours spent on assignment |
| note | string \| null | Student note |
| ignore_late_penalty | boolean | Whether late penalty is ignored |
| upload | string | Upload URL path |
| team | object \| null | Team information |

### Team

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Team ID |
| teamset_id | integer | Teamset ID |
| active | boolean | Whether team is active |
| members | array | List of team members |

### Team Member

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Registration ID |
| user_id | integer | User ID |
| name | string | User display name |

### Reg (Staff API only)

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Registration ID |
| is_grader | boolean | Whether user is grader |
| is_staff | boolean | Whether user is staff |
| is_prof | boolean | Whether user is professor |
| is_student | boolean | Whether user is student |
| user_id | integer | User ID |
| user | object | User information |
| course_id | integer | Course ID |
| course | object | Course information |
| section | string \| null | Section name |

### Grade

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Grade ID |
| score | decimal \| null | Final score |
| grade_column_id | integer | Grade column ID |
| grade_column | object | Grade column information |
| log_uuid | string \| null | Log UUID for grading script output |
| line_comments | array | List of line comments |

### Line Comment

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Line comment ID |
| path | string | File path: for single file submissions, the filename; for archive submissions, the path within the archive |
| line | integer | Line number in the file |
| points | decimal | Point adjustment (can be negative) |
| text | string | Comment text |
| user_id | integer | User ID of the grader |
| user | object | User information |
| grade_id | integer | Grade ID |

### Grade Column

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Grade column ID |
| name | string | Grade column name |
| kind | string | Column type: "number", "feedback", or "script" |
| points | decimal | Points available |
| base | decimal | Starting points before grading |