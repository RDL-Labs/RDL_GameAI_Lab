using Test, Serialization
include("../../src/lw/LW.jl")
@testset "own nutrient demand, experienced food, frozen trade value" begin
    body=LW.Body(10.,0.,100.,0.)
    sugar=LW.Digestion(macronutrients=true);sugar.macro_body.body.sugar=0.
    protein=LW.Digestion(macronutrients=true);protein.macro_body.body.amino=0.
    memory=LW.D()
    for kind in (1,7);LW.food_remember_taste!(memory,kind,2,1.,0);end
    saved=deepcopy(memory)
    sugar_values=LW.food_trade_weights(body,sugar;map=memory)
    protein_values=LW.food_trade_weights(body,protein;map=memory)
    @test sugar_values[1]>sugar_values[7]
    @test protein_values[7]>protein_values[1]
    @test memory==saved # current need must not rewrite the remembered taste
    @test LW.food_nutrient_trade_evidence(nothing,protein,7).utility==0
    @test LW.food_nutrient_trade_evidence(memory,protein,2).utility==0 # meat not experienced
    @test LW.food_nutrient_trade_evidence(memory,LW.Digestion(),7).utility==0
    @test LW.food_nutrient_trade_evidence(memory,protein,7).composition==(0.,.82,.18)
    stock=zeros(Int,8);stock[1]=2;stock[7]=2
    @test LW.food_trade_gain(stock,protein_values,1,1,7,1)>LW.food_trade_gain(stock,sugar_values,1,1,7,1)
    valuation=LW.trade_valuation_context(body,protein,nothing,LW.D(),nothing)
    @test valuation["nutrient_demand"]==(0.,1.,0.)
    outcome=LW.D("status"=>"exchanged","own_before"=>stock,"own_after"=>stock.+[ -1,0,0,0,0,0,1,0])
    expected=LW.food_trade_actual(protein_values,outcome;valuation)
    protein.macro_body.body.amino=8.
    @test LW.food_trade_actual(protein_values,outcome;valuation)==expected
    @test LW.food_nutrient_trade_evidence(memory,protein,7).utility==0
    buf=IOBuffer();serialize(buf,memory);seekstart(buf)
    @test LW.food_trade_weights(body,sugar;map=deserialize(buf))==sugar_values
    # Raw ingredients can recall a known cooked outcome only with a local facility.
    facility=(id=1,name="test",x=0.,z=0.,work_radius=2.,height=1.,radius=.5,color="brown",processing_kinds=[5])
    kitchen=(foods=nothing,actor="npc_a",facilities=[facility],position=(0.,0.),processing=true)
    protein.macro_body.body.amino=0.
    cooked=LW.food_trade_evaluation(body,protein,5;map=memory,kitchen)
    @test cooked.output==7
    @test cooked.nutrition.utility≈.82
    @test LW.food_trade_evaluation(body,protein,5;map=memory).nutrition===nothing
end

@testset "received private offer uses owner's nutrient weights" begin
    body=LW.Body(10.,0.,100.,0.);memory=LW.D()
    for kind in (1,7);LW.food_remember_taste!(memory,kind,2,1.,0);end
    stock=zeros(Int,8);stock[1]=4
    offered=zeros(Int,8);offered[7]=2
    requested=zeros(Int,8);requested[1]=1
    proposal=LW.D("id"=>1,"proposer"=>"npc_a","give_items"=>Int[],"want_items"=>Int[],
        "give_food"=>offered,"want_food"=>requested,"created_us"=>0,"expires_us"=>100_000_000)
    observed=LW.D("own"=>LW.D("held"=>Any[],"stored"=>Any[]),"visible"=>Any[],
        "incoming"=>Any[proposal],"outgoing"=>nothing,"partners"=>["npc_a"])
    @test !haskey(observed,"observed_food_stocks")
    plans=Any[]
    for nutrient in (:sugar,:protein)
        gut=LW.Digestion(macronutrients=true)
        nutrient==:sugar ? (gut.macro_body.body.sugar=0.) : (gut.macro_body.body.amino=0.)
        state=LW.incidental_item_state("npc_b",1)
        plan=LW.item_social_plan!(state,deepcopy(observed),body,gut,stock,1;map=memory)
        @test plan!==nothing
        @test plan["item_social_role"]=="response"
        @test plan["weights"]==LW.food_trade_weights(body,gut;map=memory)
        push!(plans,plan)
    end
    @test plans[2]["weights"][7]>plans[1]["weights"][7]
    @test plans[2]["weights"][1]<plans[1]["weights"][1]
    @test stock[1]==4 && sum(stock)==4 # selection itself transfers nothing
end
