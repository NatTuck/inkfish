# Inkfish API v1 Guide

This guide provides comprehensive documentation for the Inkfish API v1, enabling developers to build API clients that access all exposed functionality.

## Overview

- **Base URL**: `https://inkfish.homework.quest/api/v1`
- **Authentication**: API key via `x-auth` header
- **Content-Type**: `application/json` (except file uploads)
- **Response Format**: JSON with data wrapper
- **API Version**: v1

## Authentication

### API Key Setup

1. Generate an API key through the web interface or programmatically
2. Include the API key in all requests using the `x-auth` header
3. Users can create up to 10 API keys

### Authentication Header

```
x-auth: YOUR_API_KEY_HERE
```

### Authorization Levels

- **Student Access**: Course registration required
- **Staff Access**: Course registration + staff privileges required
- **Admin Access**: Additional admin privileges (not covered in API v1)

## Error Handling

All endpoints use consistent error responses:

- **200 OK**: Successful request
- **201 Created**: Resource created successfully
- **204 No Content**: Resource deleted successfully
- **400 Bad Request**: Missing or invalid parameters
- **403 Forbidden**: Invalid API key or insufficient permissions
- **404 Not Found**: Resource not found
- **422 Unprocessable Entity**: Validation errors with detailed changeset

### Error Response Format

```json
{
  "errors": {
    "field_name": ["error message 1", "error message 2"]
  }
}
```

## Student API Endpoints

### Submissions

#### List Submissions

**Endpoint**: `GET /api/v1/subs`

**Purpose**: List submissions for a specific assignment

**Parameters**:
- `assignment_id` (required, string) - Assignment identifier
- `page` (optional, string, default: "0") - Pagination page number

**Request**:
```bash
curl -X GET \
  -H "x-auth: YOUR_API_KEY" \
  "http://localhost:4000/api/v1/subs?assignment_id=22&page=0"
```

**Response**:
```json
{
  "data": [
    {
      "id": "submission_id",
      "active": true,
      "late_penalty": 0.0,
      "score": 85.5,
      "hours_spent": 3.5,
      "note": "Optional student note",
      "ignore_late_penalty": false,
      "upload": "/uploads/uuid/filename.ext"
    }
  ]
}
```

#### Get Submission Details

**Endpoint**: `GET /api/v1/subs/:id`

**Purpose**: Get details of a specific submission

**Parameters**:
- `id` (required, string) - Submission identifier

**Request**:
```bash
curl -X GET \
  -H "x-auth: YOUR_API_KEY" \
  "http://localhost:4000/api/v1/subs/submission_id"
```

**Response**: Same format as individual submission object in list response

#### Upload Submission

**Endpoint**: `POST /api/v1/subs`

**Purpose**: Upload a new submission

**Content-Type**: `multipart/form-data`

**Parameters**:
- `sub[upload]` (required, file) - File to upload
- `sub[assignment_id]` (required, string) - Assignment ID
- `sub[hours_spent]` (optional, number) - Hours spent on assignment

**Request**:
```bash
curl -X POST \
  -H "x-auth: YOUR_API_KEY" \
  -F "sub[upload]=@/path/to/file.ext" \
  -F "sub[assignment_id]=22" \
  -F "sub[hours_spent]=3.5" \
  "http://localhost:4000/api/v1/subs"
```

**Response** (201 Created):
```json
{
  "data": {
    "id": "new_submission_id",
    "active": true,
    "late_penalty": 0.0,
    "score": null,
    "hours_spent": 3.5,
    "note": null,
    "ignore_late_penalty": false,
    "upload": "/uploads/uuid/filename.ext"
  }
}
```

**Response** (422 Unprocessable Entity):
```json
{
  "errors": {
    "upload": ["can't be blank"],
    "assignment_id": ["is invalid"]
  }
}
```

## Staff API Endpoints

### Dashboard

#### Get Staff Dashboard

**Endpoint**: `GET /api/v1/staff/dashboard`

**Purpose**: Get an overview of all courses the user has staff access to, including assignments needing grades and upcoming assignments

**Authorization**: Staff or professor privileges required

**Request**:
```bash
curl -X GET \
  -H "x-auth: YOUR_API_KEY" \
  "http://localhost:4000/api/v1/staff/dashboard"
```

**Response**:
```json
{
  "courses": [
    {
      "id": 1,
      "name": "CS 101",
      "past_assignments_with_ungraded": [
        {
          "id": 5,
          "name": "Homework 3",
          "due": "2026-02-20T23:00:00",
          "bucket_name": "Homework",
          "course_id": 1,
          "ungraded_count": 3,
          "total_count": 30,
          "overdue": true
        }
      ],
      "upcoming_by_bucket": {
        "Homework": [
          {
            "id": 6,
            "name": "Homework 4",
            "due": "2026-03-01T23:00:00"
          }
        ],
        "Projects": [],
        "Labs": []
      }
    }
  ]
}
```

**Response Fields**:
- `courses`: List of courses the user has staff access to
- `past_assignments_with_ungraded`: Assignments with due dates in the past that have ungraded submissions
  - `overdue`: True if the assignment is more than 4 days past due
  - `ungraded_count`: Number of submissions needing grades
  - `total_count`: Total number of active submissions
- `upcoming_by_bucket`: Upcoming assignments grouped by bucket name (top 2 per bucket)
  - Empty arrays indicate buckets with no upcoming assignments

**Use Case**: This endpoint provides a comprehensive overview for grading workflows. A client can:
1. Fetch the dashboard to see all courses
2. For each course, iterate through `past_assignments_with_ungraded`
3. Use each assignment's `id` to call `GET /api/v1/staff/subs?assignment_id=X` to fetch submissions needing grades

### Assignments

#### Get Assignment Details

**Endpoint**: `GET /api/v1/staff/assignments/:id`

**Purpose**: Get comprehensive assignment details

**Authorization**: Staff privileges required

**Parameters**:
- `id` (required, string) - Assignment identifier

**Request**:
```bash
curl -X GET \
  -H "x-auth: YOUR_API_KEY" \
  "http://localhost:4000/api/v1/staff/assignments/assignment_id"
```

**Response**:
```json
{
  "data": {
    "id": "assignment_id",
    "name": "Assignment Name",
    "due": "2024-01-15T23:59:59Z",
    "bucket": {
      "id": "bucket_id",
      "name": "Bucket Name"
    },
    "teamset": {
      "id": "teamset_id",
      "name": "Teamset Name"
    },
    "grade_columns": [
      {
        "id": "grade_column_id",
        "name": "Feedback",
        "points": 100.0,
        "kind": "feedback"
      }
    ],
    "subs": [
      {
        "id": "submission_id",
        "active": true,
        "score": 85.5
      }
    ],
    "desc": "Assignment description",
    "starter_upload": "/uploads/uuid/starter.zip",
    "solution_upload": "/uploads/uuid/solution.zip"
  }
}
```

### Submissions (Staff View)

#### List All Submissions

**Endpoint**: `GET /api/v1/staff/subs`

**Purpose**: List all submissions for an assignment (staff view with registration details)

**Authorization**: Staff privileges required

**Parameters**:
- `assignment_id` (required, string) - Assignment ID
- `page` (optional, string, default: "0") - Pagination page number

**Request**:
```bash
curl -X GET \
  -H "x-auth: YOUR_API_KEY" \
  "http://localhost:4000/api/v1/staff/subs?assignment_id=22&page=0"
```

**Response**:
```json
{
  "data": [
    {
      "id": "submission_id",
      "active": true,
      "late_penalty": 0.0,
      "score": 85.5,
      "hours_spent": 3.5,
      "note": "Student note",
      "ignore_late_penalty": false,
      "upload": "/uploads/uuid/filename.ext",
      "reg": {
        "id": "registration_id",
        "user": {
          "id": "user_id",
          "email": "student@example.com",
          "given_name": "John",
          "family_name": "Doe"
        }
      }
    }
  ]
}
```

#### Get Submission Details (Staff View)

**Endpoint**: `GET /api/v1/staff/subs/:id`

**Purpose**: Get detailed submission information with registration details

**Authorization**: Staff privileges required

**Parameters**:
- `id` (required, string) - Submission identifier

**Request**:
```bash
curl -X GET \
  -H "x-auth: YOUR_API_KEY" \
  "http://localhost:4000/api/v1/staff/subs/submission_id"
```

**Response**: Same format as individual submission object in list response

### Grades

#### List Grades for Submission

**Endpoint**: `GET /api/v1/staff/grades`

**Purpose**: List all grades for a specific submission

**Authorization**: Staff privileges required

**Parameters**:
- `sub_id` (required, string) - Submission identifier

**Request**:
```bash
curl -X GET \
  -H "x-auth: YOUR_API_KEY" \
  "http://localhost:4000/api/v1/staff/grades?sub_id=submission_id"
```

**Response**:
```json
{
  "data": [
    {
      "id": "grade_id",
      "score": 85.5,
      "log_uuid": "autograder_log_uuid",
      "line_comments": [
        {
          "id": "comment_id",
          "line": 42,
          "comment": "Good work here",
          "points": 5.0
        }
      ]
    }
  ]
}
```

#### Create Grade

**Endpoint**: `POST /api/v1/staff/grades`

**Purpose**: Create a new grade for a submission

**Authorization**: Staff privileges required

**Parameters**:
- `sub_id` (required, string) - Submission identifier
- `grade` (required, object) - Grade parameters

**Request**:
```bash
curl -X POST \
  -H "x-auth: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "sub_id": "submission_id",
    "grade": {
      "score": 90.0,
      "line_comments": [
        {
          "line": 10,
          "comment": "Excellent implementation",
          "points": 5.0
        }
      ]
    }
  }' \
  "http://localhost:4000/api/v1/staff/grades"
```

**Response** (201 Created):
```json
{
  "data": {
    "id": "new_grade_id",
    "score": 90.0,
    "log_uuid": null,
    "line_comments": [
      {
        "id": "comment_id",
        "line": 10,
        "comment": "Excellent implementation",
        "points": 5.0
      }
    ]
  }
}
```

#### Get Grade Details

**Endpoint**: `GET /api/v1/staff/grades/:id`

**Purpose**: Get specific grade details

**Authorization**: Staff privileges required

**Parameters**:
- `id` (required, string) - Grade identifier

**Request**:
```bash
curl -X GET \
  -H "x-auth: YOUR_API_KEY" \
  "http://localhost:4000/api/v1/staff/grades/grade_id"
```

**Response**: Same format as individual grade object in list response

#### Delete Grade

**Endpoint**: `DELETE /api/v1/staff/grades/:id`

**Purpose**: Delete a grade

**Authorization**: Staff privileges required

**Parameters**:
- `id` (required, string) - Grade identifier

**Request**:
```bash
curl -X DELETE \
  -H "x-auth: YOUR_API_KEY" \
  "http://localhost:4000/api/v1/staff/grades/grade_id"
```

**Response**: 204 No Content

## Client Implementation Examples

### Elixir (Req)

```elixir
defmodule InkfishAPIClient do
  @base_url "http://localhost:4000/api/v1"
  
  def list_submissions(api_key, assignment_id, page \\ 0) do
    headers = [{"x-auth", api_key}]
    
    Req.get!("#{@base_url}/subs?assignment_id=#{assignment_id}&page=#{page}", headers: headers)
  end
  
  def upload_submission(api_key, assignment_id, file_path, hours_spent \\ nil) do
    headers = [{"x-auth", api_key}]
    
    multipart = Req.post_multipart([
      {"sub[upload]", Req.File.open!(file_path)},
      {"sub[assignment_id]", assignment_id},
      {"sub[hours_spent]", hours_spent}
    ])
    
    Req.post!("#{@base_url}/subs", headers: headers, body: multipart)
  end
  
  def create_grade(api_key, submission_id, score, line_comments \\ []) do
    headers = [{"x-auth", api_key}, {"content-type", "application/json"}]
    
    body = Jason.encode!(%{
      sub_id: submission_id,
      grade: %{
        score: score,
        line_comments: line_comments
      }
    })
    
    Req.post!("#{@base_url}/staff/grades", headers: headers, body: body)
  end
end
```

### Python (requests)

```python
import requests
import json

class InkfishAPIClient:
    def __init__(self, api_key, base_url="http://localhost:4000/api/v1"):
        self.api_key = api_key
        self.base_url = base_url
        self.headers = {"x-auth": api_key}
    
    def list_submissions(self, assignment_id, page=0):
        """List submissions for an assignment."""
        url = f"{self.base_url}/subs"
        params = {"assignment_id": assignment_id, "page": page}
        response = requests.get(url, headers=self.headers, params=params)
        response.raise_for_status()
        return response.json()
    
    def upload_submission(self, assignment_id, file_path, hours_spent=None):
        """Upload a new submission."""
        url = f"{self.base_url}/subs"
        data = {
            "sub[assignment_id]": assignment_id,
            "sub[hours_spent]": hours_spent
        }
        
        with open(file_path, 'rb') as f:
            files = {"sub[upload]": f}
            response = requests.post(url, headers=self.headers, data=data, files=files)
        
        response.raise_for_status()
        return response.json()
    
    def create_grade(self, submission_id, score, line_comments=None):
        """Create a new grade for a submission."""
        url = f"{self.base_url}/staff/grades"
        self.headers["content-type"] = "application/json"
        
        payload = {
            "sub_id": submission_id,
            "grade": {
                "score": score,
                "line_comments": line_comments or []
            }
        }
        
        response = requests.post(url, headers=self.headers, data=json.dumps(payload))
        response.raise_for_status()
        return response.json()
    
    def get_assignment_details(self, assignment_id):
        """Get assignment details (staff only)."""
        url = f"{self.base_url}/staff/assignments/{assignment_id}"
        response = requests.get(url, headers=self.headers)
        response.raise_for_status()
        return response.json()
```

### JavaScript (fetch)

```javascript
class InkfishAPIClient {
  constructor(apiKey, baseUrl = 'http://localhost:4000/api/v1') {
    this.apiKey = apiKey;
    this.baseUrl = baseUrl;
    this.headers = {
      'x-auth': apiKey,
      'Content-Type': 'application/json'
    };
  }

  async listSubmissions(assignmentId, page = 0) {
    const url = `${this.baseUrl}/subs?assignment_id=${assignmentId}&page=${page}`;
    const response = await fetch(url, { headers: this.headers });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    return await response.json();
  }

  async uploadSubmission(assignmentId, file, hoursSpent = null) {
    const formData = new FormData();
    formData.append('sub[upload]', file);
    formData.append('sub[assignment_id]', assignmentId);
    
    if (hoursSpent !== null) {
      formData.append('sub[hours_spent]', hoursSpent.toString());
    }

    const headers = { 'x-auth': this.apiKey };
    const response = await fetch(`${this.baseUrl}/subs`, {
      method: 'POST',
      headers: headers,
      body: formData
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    return await response.json();
  }

  async createGrade(submissionId, score, lineComments = []) {
    const payload = {
      sub_id: submissionId,
      grade: {
        score: score,
        line_comments: lineComments
      }
    };

    const response = await fetch(`${this.baseUrl}/staff/grades`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    return await response.json();
  }
}
```

## Rate Limiting and Best Practices

1. **Pagination**: Use the `page` parameter for large result sets
2. **File Uploads**: Use multipart/form-data for submission uploads
3. **Error Handling**: Always check HTTP status codes and handle error responses
4. **API Key Security**: Never expose API keys in client-side code
5. **Idempotency**: DELETE operations are idempotent, POST operations are not

## Testing

Use the provided demo scripts for testing:

```bash
# Elixir demo
cd scripts && elixir api-demo.exs

# Shell demo
export INKFISH_KEY="your_api_key_here"
./scripts/api-list-subs.sh
```

## Support

For API support and questions, refer to the application documentation or contact the development team.
