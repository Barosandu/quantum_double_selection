using Base.Threads
using WGLMakie
WGLMakie.activate!()
using JSServe
using Markdown


# 1. LOAD LAYOUT HELPER FUNCTION AND UTILSm    
include("layout_utils.jl")
include("plots.jl")

## config sizes TODO: make linear w.r.t screen size
config = Dict(
    :resolution => (1400, 700), #used for the main figures
    :smallresolution => (280, 160) #used for the menufigures
)

###################### 2. LAYOUT ######################
#   Returns the reactive (click events handled by zstack!)
#   layout of the activefigure (mainfigure)
#   and menufigures (the small figures at the top which get
#   clicked)

function layout_content(DOM, mainfigures #TODO: remove DOM param
    , menufigures, title_zstack, session, active_index)
    
    menufigs_andtitles = wrap([vstack(hoverable!(menufigures[i], class="border"; session=session, observable=@lift($active_index == i)),
                        title_zstack[i]; class="justify-center align-center ") for i in 1:3];
                class="menufigs", style="width: $(config[:resolution][1])px")
    
   
    activefig = zstack!(
                active(mainfigures[1]),
                wrap(mainfigures[2]),
                wrap(mainfigures[3]);
                session=session, observable=active_index,
                style="width: $(config[:resolution][1])px",
                class="activefig")
    
    content = Dict(
        :activefig => activefig,
        :menufigs => menufigs_andtitles
    )
    return DOM.div(menufigs_andtitles, formatstyle, activefig), content

end


###################### 4. LANDING PAGE OF THE APP ######################

landing = App() do session::Session
    
    # Create the menufigures and the mainfigures
    mainfigures = [Figure(backgroundcolor=:white,  resolution=config[:resolution]) for _ in 1:3]
    menufigures = [Figure(backgroundcolor=:white,  resolution=config[:smallresolution]) for _ in 1:3]
    titles= ["Entanglement Generation",
    "Entanglement Swapping",
    "Entanglement Purification"]
    # Active index: 1 2 or 3
    #   1: the first a.k.a alpha (Entanglement Generation) figure is active
    #   2: the second a.k.a beta (Entanglement Swapping) figure is active    
    #   3: the third a.k.a gamma (Entanglement Purification) figure is active
    activeidx = Observable(1)
    hoveredidx = Observable(0)

    # CLICK EVENT LISTENERS
    for i in 1:3
        on(events(menufigures[i]).mousebutton) do event
            activeidx[]=i  
            notify(activeidx)
        end
        on(events(menufigures[i]).mouseposition) do event
            hoveredidx[]=i  
            notify(hoveredidx)
        end
        
        # TODO: figure out when mouse leaves and set hoverableidx[] to 0
    end

    # Using the aforementioned plot function to plot for each figure array
    plot(mainfigures)
    plot(menufigures; hidedecor=true)

    
    # Create ZStacks displayong titles below the menu graphs
    titles_zstack = [DOM.h4(t, class="upper") for t in titles]
    for i in 1:3
        titles_zstack[i] = zstack!(titles_zstack[i], wrap(""), wrap(""); 
                                        observable=@lift(($hoveredidx == i || $activeidx == i)),
                                        session=session,
                                        class="opacity")
    end

    # Obtain reactive layout of the figures
    
    layout, content = layout_content(DOM, mainfigures, menufigures, titles_zstack, session, activeidx)

    # Add title to the right in the form of a ZStack
    titles_div = [DOM.h1(t) for t in titles]
    titles_div[1] = active(titles_div[1])
    titles_div = zstack!(titles_div; observable=activeidx, session=session, class="static") # static = no animation
    
    
    return hstack(layout, hstack(titles_div; style="padding: 20px; 
                                background-color: rgb(229, 229, 236);"); style="width: 100%;")

end



##
# Serve the Makie app

isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_COLORCENTERMODCLUSTER_PORT", "8889"))
interface = get(ENV, "QS_COLORCENTERMODCLUSTER_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_COLORCENTERMODCLUSTER_PROXY", "")
server = JSServe.Server(interface, port; proxy_url);
JSServe.HTTPServer.start(server)
JSServe.route!(server, "/" => landing);

##

wait(server)