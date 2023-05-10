local Installer={}

function Installer:new(args)
  local m=setmetatable({},{__index=Installer})
  local args=args==nil and {} or args
  for k,v in pairs(args) do
    m[k]=v
  end
  m:init()
  return m
end

function Installer:split_path(path)
    -- https://stackoverflow.com/questions/5243179/what-is-the-neatest-way-to-split-out-a-path-name-into-its-components-in-lua
    -- /home/zns/1.txt returns
    -- /home/zns/   1.txt   txt
    pathname,filename,ext=string.match(path,"(.-)([^\\/]-%.?([^%.\\/]*))$")
    return pathname,filename,ext
end

function Installer:list_folders(directory)
    local i,t,popen=0,{},io.popen
    local pfile=popen('ls -pL --group-directories-first "'..directory..'"')
    for filename in pfile:lines() do
        i=i+1
        t[i]=filename
    end
    pfile:close()
    return t
end

function Installer:list_files(dir)
    local delim="!"
    local file_list=os_capture(string.format("find %s -type f ",dir).."-printf '%p"..delim.."'")
    local files={}
    for _,t in ipairs(split_delimiter(file_list,delim)) do
        if #t>2 then
            table.insert(files,t)
        end
    end
    return files
end


function Installer:init()
    if self.zip=="" then 
        print("NEED TO SPECIFY ZIP FILE")
    end
    self.requirements=self.requirements or {}

    self.ready_to_restart=false
    self.satisfied=false

    -- make sure all requirements are satisfied
    local has_requirements={}
    local num_requirements = 0
    for _, r in ipairs(self.has_requirements) do 
        has_requirements[r]=false
    end
    num_requirements=#has_requirements

    -- find all the supercollider files
    local folders_to_check={
        "/usr/local/share/SuperCollider/Extensions",
        "/home/we/dust/code",
        "/home/we/.local/share/SuperCollider/Extensions",
    }
    local num_requirements_found = 0
    for _,folder in ipairs(folders_to_check) do
        for _,file in ipairs(self:list_files(folder)) do
            if not string.find(file,"ignore") then 
                folder,filename,_=self:split_path(file)
                if string.find(folder,"/ignore/") then 
                else
                    for k,found in pairs(has_requirements) do 
                        if not found then 
                            if string.find(filename,k) then 
                                has_requirements[k]=true 
                                num_requirements_found = num_requirements_found + 1
                                if num_requirements == num_requirements_found then 
                                    self.satisfied = true
                                    do return true end 
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    -- create array of just the missing pieces
    self.missing_requirements={}
    for k,found in pairs(has_requirements) do 
        if not found then 
            table.insert(self.missing_requirements,k)
        end
    end
    self.message_needed=table.concat(self.missing_requirements, ",")
    return false
end

function Installer:ready()
    return self.satisfied
end

function Installer:install() 
    self.installing = true 
    -- download
    os.execute("mkdir -p /tmp/norns-installer/ignore")
    os.execute("wget -q -O /tmp/norns-installer/ignore/bundle.zip "..self.zip)
    os.execute("cd tmp/norns-installer/ignore/ && unzip -o -q bundle.zip")
    -- find relevant files and copy them
    os.execute("/home/we/.local/share/SuperCollider/Extensions/supercollider-plugins")
    for _,file in ipairs(self:list_files(folder)) do
        if not string.find(file,"ignore") then 
            _,filename,_=self:split_path(file)
            for _, file_needed in ipairs(self.missing_requirements) do 
                if string.find(filename,file_needed) then 
                    -- copy it
                    print("copying "..filename.." to Extensions...")
                    os.execute(string.format("cp %s /home/we/.local/share/SuperCollider/Extensions/supercollider-plugins/",file))
                end
            end
        end
    end
    os.execute("cd /tmp/ && rm -rf norns-installer")
    self.ready_to_restart=true
    self.installing=false
end

function Installer:key(k,z) 
    if self.satisfied or self.ready_to_restart or self.installing then 
        do return end 
    end
    if k==3 and z==1 then 
        self:install()
    end
end

function Installer:redraw()
    screen.clear()
    screen.blend_mode(0)
    screen.level(15)
    if self.ready_to_restart then 
        screen.move(64,32)
        screen.text_center("ready. do SYSTEM -> RESTART.")
        screen.move(64,42)
        screen.text_center("then reload this script.")
        do return end 
    end
    if self.installing then 
        screen.move(64,32)
        screen.text_center("installing...")
        screen.move(64,42)
        screen.text(self.message_needed)
        do return end 
    end
    screen.move(64,32)
    screen.text("missing SuperCollider libraries:")
    screen.move(64,42)
    screen.text(self.message_needed)
    screen.move(64,52)
    screen.text("press K3 to install.")
    screen.update()
end

return Installer
