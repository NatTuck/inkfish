defmodule InkfishWeb.Router do
  use InkfishWeb, :router

  import InkfishWeb.UserAuth
  
  alias InkfishWeb.Plugs

  pipeline :browser do
    plug :accepts, ["html"]
    plug Plugs.Assign, client_mode: :browser
    plug :fetch_session
    plug Plugs.FetchUser
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    #plug :fetch_current_user
    plug Plugs.Breadcrumb, {"Home", :page, :index}
  end

  pipeline :ajax do
    plug :accepts, ["json"]
    plug Plugs.Assign, client_mode: :ajax
    plug :fetch_session
    plug Plugs.FetchUser
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end
  
  pipeline :admin do
    plug Plugs.RequireUser, is_admin: true
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", InkfishWeb do
    pipe_through :browser

    get "/", PageController, :index
    resources "/session", SessionController, only: [:create, :delete], singleton: true

    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end

  scope "/", InkfishWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/dashboard", PageController, :dashboard
    post "/session/resume", SessionController, :resume
    resources "/users", UserController, only: [:show, :edit, :update]
    resources "/uploads", UploadController, only: [:create, :show]
    get "/uploads/:id/_meta/thumb", UploadController, :thumb
    get "/uploads/:id/_meta/unpacked/*path", UploadController, :unpacked
    get "/uploads/:id/:name", UploadController, :download
    resources "/courses", CourseController, only: [:index, :show] do
      resources "/join_reqs", JoinReqController, only: [:new, :create]
    end
    resources "/regs", RegController, only: [:show]
    resources "/teams", TeamController, only: [:show]
    resources "/assignments", AssignmentController, only: [:show] do
      resources "/subs", SubController, only: [:new, :create]
    end
    resources "/subs", SubController, only: [:show]
    get "/subs/:id/files", SubController, :files
    #resources "/grade_columns", GradeColumnController, only: [:show]
    resources "/grades", GradeController, only: [:show]
  end

  scope "/", InkfishWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/staff", InkfishWeb.Staff, as: :staff do
    pipe_through :browser

    resources "/courses", CourseController, only: [:index, :show, :edit, :update] do
      resources "/regs", RegController, only: [:index, :new, :create]
      resources "/join_reqs", JoinReqController, only: [:index]
      resources "/teamsets", TeamsetController, only: [:index, :new, :create]
      resources "/buckets", BucketController, only: [:index, :new, :create]
      post "/join_reqs/accept_all", JoinReqController, :accept_all
    end
    get "/courses/:id/gradesheet", CourseController, :gradesheet
    get "/courses/:id/tasks", CourseController, :tasks
    resources "/regs", RegController, except: [:index, :new, :create]
    resources "/join_reqs", JoinReqController, only: [:show, :delete]
    post "/join_reqs/:id/accept", JoinReqController, :accept
    resources "/teamsets", TeamsetController, except: [:index, :new, :create]
    resources "/buckets", BucketController, except: [:index, :new, :create] do
      resources "/assignments", AssignmentController, only: [:new, :create]
    end
    resources "/assignments", AssignmentController, except: [:index, :new, :create] do
      resources "/grade_columns", GradeColumnController, only: [:index, :new, :create]
      resources "/grading_tasks", GradingTaskController,
        except: [:new, :delete], singleton: true
    end
    post "/assignments/:id/create_fake_subs", AssignmentController, :create_fake_subs
    resources "/grade_columns", GradeColumnController, except: [:index, :new, :create]
    resources "/subs", SubController, only: [:show, :update] do
      resources "/grades", GradeController, only: [:create]
    end
    resources "/grades", GradeController, only: [:edit, :show]
    post "/grades/:id/rerun_script", GradeController, :rerun_script
  end

  scope "/admin", InkfishWeb.Admin, as: :admin do
    pipe_through [:browser, :admin]
    
    resources "/users", UserController, except: [:new, :create]
    post "/users/:id/impersonate", UserController, :impersonate
    resources "/courses", CourseController
    resources "/uploads", UploadController, only: [:index]
  end

  scope "/ajax", InkfishWeb, as: :ajax do
    pipe_through :ajax

    post "/uploads", UploadController, :create
  end

  scope "/ajax/staff", InkfishWeb.Staff, as: :ajax_staff do
    pipe_through :ajax

    resources "/subs", SubController, only: [:update] do
      resources "/grades", GradeController, only: [:create]
    end
    resources "/grades", GradeController, only: [] do
      resources "/line_comments", LineCommentController, only: [:create]
    end
    resources "/line_comments", LineCommentController, only: [:show, :update, :delete]
    resources "/teamsets", TeamsetController, only: [] do
      resources "/teams", TeamController, only: [:index, :create]
    end
    resources "/teams", TeamController, only: [:show, :update, :delete]
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/live_dashboard", metrics: InkfishWeb.Telemetry
    end
  end
end
