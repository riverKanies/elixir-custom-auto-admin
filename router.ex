# ...
  
  scope "/autoadmin", MyApp do
    pipe_through ~w(browser)a # ~w(browser auth)a
    get("/index/:schema", AutoAdminController, :index)
    get("/edit/:schema/:id", AutoAdminController, :edit)
    post("/new/:schema/:id", AutoAdminController, :create)
    put("/update/:schema/:id", AutoAdminController, :update)
  end

# ...