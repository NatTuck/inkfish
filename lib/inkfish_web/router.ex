defmodule InkfishWeb.Router do
  use InkfishWeb, :router

  import Phoenix.LiveDashboard.Router

  alias InkfishWeb.Plugs
  import Plugs.UserSession

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(Plugs.Assign, client_mode: :browser)
    plug(:fetch_session)
    plug(Plugs.FetchUser)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(Plugs.Breadcrumb, {"Home", :page, :index})
  end

  pipeline :ajax do
    plug(:accepts, ["json"])
    plug(Plugs.Assign, client_mode: :ajax)
    plug(:fetch_session)
    plug(Plugs.FetchUser)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(Plugs.Assign, client_mode: :api)
  end

  scope "/", InkfishWeb do
    pipe_through(:browser)

    get("/", PageController, :index)

    resources("/session", SessionController,
      only: [:create, :delete],
      singleton: true
    )

    # Downloading an upload by uuid should be OK
    # because UUIDs are hard to guess.
    get("/uploads/:id/:name", UploadController, :download)
  end

  scope "/", InkfishWeb do
    pipe_through([:browser, :require_no_session])

    post("/users/send_auth_email", UserAuthEmailController, :create)
    get("/users/auth/:token", UserAuthEmailController, :show)
    get("/users/new/:token", UserController, :new)
    post("/users", UserController, :create)
  end

  scope "/", InkfishWeb do
    pipe_through([:browser, :require_user_session])

    get("/dashboard", PageController, :dashboard)
    post("/session/resume", SessionController, :resume)
    resources("/users", UserController, only: [:show, :edit, :update])
    resources("/uploads", UploadController, only: [:create, :show])
    get("/uploads/:id/_meta/thumb", UploadController, :thumb)
    get("/uploads/:id/_meta/unpacked/*path", UploadController, :unpacked)

    resources "/courses", CourseController, only: [:index, :show] do
      resources("/join_reqs", JoinReqController, only: [:new, :create])
      resources("/meetings", MeetingController, only: [:index])
    end

    resources("/regs", RegController, only: [:show])
    resources("/teams", TeamController, only: [:show])

    resources "/assignments", AssignmentController, only: [:show] do
      resources("/subs", SubController, only: [:new, :create])
    end

    resources("/subs", SubController, only: [:show])
    get("/subs/:id/files", SubController, :files)
    post("/subs/:id/rerun_scripts", SubController, :rerun_scripts)
    # resources "/grade_columns", GradeColumnController, only: [:show]
    resources("/grades", GradeController, only: [:show])

    resources("/ag_jobs", AgJobController, only: [:index])
    post("/ag_jobs/poll", AgJobController, :poll)

    resources("/api_keys", ApiKeyController, except: [:edit, :update])
  end

  scope "/staff", InkfishWeb.Staff, as: :staff do
    pipe_through([:browser, :require_user_session])

    resources "/courses", CourseController,
      only: [:index, :show, :edit, :update] do
      resources("/regs", RegController, only: [:index, :new, :create])
      resources("/join_reqs", JoinReqController, only: [:index])
      resources("/teamsets", TeamsetController, only: [:index, :new, :create])
      resources("/buckets", BucketController, only: [:index, :new, :create])
      resources("/meetings", MeetingController, only: [:index, :new, :create])
      post("/join_reqs/accept_all", JoinReqController, :accept_all)
    end

    get("/courses/:id/gradesheet", CourseController, :gradesheet)
    get("/courses/:id/tasks", CourseController, :tasks)
    resources("/regs", RegController, except: [:index, :new, :create])
    resources("/join_reqs", JoinReqController, only: [:show, :delete])
    post("/join_reqs/:id/accept", JoinReqController, :accept)
    resources("/teamsets", TeamsetController, except: [:index, :new, :create])
    post("/teamsets/:id/add_prof_team", TeamsetController, :add_prof_team)

    resources "/buckets", BucketController, except: [:index, :new, :create] do
      resources("/assignments", AssignmentController, only: [:new, :create])
    end

    resources("/meetings", MeetingController,
      except: [:index, :new, :create]
    ) do
      resources "/attendances", AttendanceController, only: [:index]
    end

    resources "/attendances", AttendanceController,
      only: [:show, :edit, :update, :delete]

    resources "/assignments", AssignmentController,
      except: [:index, :new, :create] do
      resources("/grade_columns", GradeColumnController,
        only: [:index, :new, :create]
      )

      resources("/grading_tasks", GradingTaskController,
        except: [:new, :delete],
        singleton: true
      )
    end

    post(
      "/assignments/:id/create_fake_subs",
      AssignmentController,
      :create_fake_subs
    )

    resources("/grade_columns", GradeColumnController,
      except: [:index, :new, :create]
    )

    resources "/subs", SubController, only: [:show, :update] do
      resources("/grades", GradeController, only: [:create])
    end

    post("/subs/:id/activate", SubController, :activate)
    post("/subs/:id/toggle_late_penalty", SubController, :toggle_late_penalty)

    resources("/grades", GradeController, only: [:edit, :show])
  end

  scope "/admin", InkfishWeb.Admin, as: :admin do
    pipe_through([:browser, :require_admin_session])

    resources("/users", UserController, except: [:new, :create])
    post("/users/:id/impersonate", UserController, :impersonate)
    resources("/courses", CourseController)
    resources("/uploads", UploadController, only: [:index])
    resources("/docker_tags", DockerTagController)
    post("/docker_tags/:id/build", DockerTagController, :build)
    post("/docker_tags/:id/clean", DockerTagController, :clean)
    live_dashboard("/live_dashboard", metrics: InkfishWeb.Telemetry)
  end

  scope "/ajax", InkfishWeb, as: :ajax do
    pipe_through([:ajax, :require_user_session])

    post("/uploads", UploadController, :create)
  end

  scope "/ajax/staff", InkfishWeb.Staff, as: :ajax_staff do
    pipe_through([:ajax, :require_user_session])

    resources "/subs", SubController, only: [:update] do
      resources("/grades", GradeController, only: [:create])
    end

    resources "/grades", GradeController, only: [] do
      resources("/line_comments", LineCommentController, only: [:create])
    end

    resources("/line_comments", LineCommentController,
      only: [:show, :update, :delete]
    )

    resources "/teamsets", TeamsetController, only: [] do
      resources("/teams", TeamController, only: [:index, :create])
    end

    resources("/teams", TeamController, only: [:show, :update, :delete])
  end

  scope "/api/v1", InkfishWeb.ApiV1, as: :api_v1 do
    pipe_through :api

    resources "/subs", SubController, only: [:index, :create, :show]
  end

  scope "/api/v1/staff", InkfishWeb.ApiV1.Staff, as: :api_v1_staff do
    pipe_through :api

    resources "/assignments", AssignmentController, only: [:show]

    resources "/subs", SubController, only: [:index, :show]

    resources "/grades", GradeController,
      only: [:index, :show, :create, :delete]
  end

  if Mix.env() in [:dev, :test] do
    scope "/dev" do
      pipe_through(:browser)
      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
