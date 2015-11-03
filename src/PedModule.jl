module PedModule

using DataFrames  

type PedNode
    seqID::Int64                                              
    sire::UTF8String
    dam::UTF8String
    f::Float64                           
end

type Pedigree                             
    currentID::Int64                            
    idMap::Dict                               
    aij::SparseMatrixCSC{Float64,Int64}
    setNG::Set                            
    setG::Set                             
    counts                               
end

function code!(ped::Pedigree,id::UTF8String) 
# The idea for this function came from a perl script by Bernt Guldbrandtsen  
    if ped.idMap[id].seqID!=0             
        return
    end
    sireID = ped.idMap[id].sire  
    damID  = ped.idMap[id].dam
    if sireID!="0" && ped.idMap[sireID].seqID==0       
        code!(ped,sireID)                          
    end 
    if damID!="0" && ped.idMap[damID].seqID==0        
        code!(ped,damID)
    end
    ped.idMap[id].seqID = ped.currentID
    ped.currentID += 1
end

function fillMap!(ped::Pedigree,df)
    n = size(df,1)                     
    for i in df[:,2]                       
        if i!="0" && !haskey(ped.idMap,i)          # skip 0 and if already done
            ped.idMap[i]=PedNode(0,"0","0",-1.0)
        end
    end
    for i in df[:,3]                      
        if i!="0" && !haskey(ped.idMap,i)         # make an entry for all dams
            ped.idMap[i]=PedNode(0,"0","0",-1.0)
        end
    end 
    j=1
    for i in df[:,1]                              
        ped.idMap[i]=PedNode(0,df[j,2],df[j,3],-1.0) 
        j+=1
    end 
end

function calcAddRel!(ped::Pedigree,id1::UTF8String,id2::UTF8String)
    #@printf "calcRel between %s and %s \n" id1 id2
    if id1=="0" || id2=="0"           # zero
        return 0.0
    end
    old,yng = ped.idMap[id1].seqID<ped.idMap[id2].seqID ? (id1,id2):(id2,id1)
    oldID = ped.idMap[old].seqID
    yngID = ped.idMap[yng].seqID
    if ped.aij[oldID,yngID]>0.0      # already done
    	ped.counts[2] += 1
        return ped.aij[yngID,oldID]
    end
    ped.counts[1] += 1
    if old==yng                       # aii
        aii = 1.0 + calcInbreeding!(ped,old)
        ped.aij[oldID,oldID] = aii
        return (aii)   
    end
    sireOfYng = ped.idMap[yng].sire
    damOfYng  = ped.idMap[yng].dam 
    aij = 0.5*(calcAddRel!(ped,old,sireOfYng) + calcAddRel!(ped,old,damOfYng))
    ped.aij[yngID,oldID] = aij
    ped.aij[oldID,yngID] = 1.0
    return(aij)
end 

function calcInbreeding!(ped::Pedigree,id::UTF8String)
    #@printf "calcInbreeding for: %s \n" id
    if ped.idMap[id].f > -1.0
        return ped.idMap[id].f
    end
    sireID = ped.idMap[id].sire
    damID  = ped.idMap[id].dam
    if (sireID=="0" || damID=="0" )
        ped.idMap[id].f = 0.0
    else
        ped.idMap[id].f = 0.5*calcAddRel!(ped,sireID,damID)
    end
end

function AInverse(ped::Pedigree)
    n = ped.currentID - 1
    Ai = spzeros(n,n)
    pos  = Int64[0,0,0]
    q    = [0.5,0.5,1.0]
    for ind in keys(ped.idMap)
        sire = ped.idMap[ind].sire
        dam  = ped.idMap[ind].dam
        pos[1] = sire=="0" ? 0: ped.idMap[sire].seqID
        pos[2] = dam =="0" ? 0: ped.idMap[dam ].seqID
        pos[3] = ped.idMap[ind].seqID
        if pos[1]>0 && pos[2]>0
            q[1] = -0.5
            q[2] = -0.5
            d = 4.0/(2 - ped.idMap[sire].f - ped.idMap[dam].f)
        elseif pos[1]>0
            q[1] = -0.5
            q[2] = 0.0
            d = 4.0/(3 - ped.idMap[sire].f)
        elseif pos[2]>0
            q[1] = 0.0
            q[2] = -0.5
            d = 4.0/(3 - ped.idMap[dam].f) 
        else
            q[1] = 0.0
            q[2] = 0.0
            d = 1.0 
        end
        for i=1:3
            ii = pos[i]
            if ii>0
                for j=1:3
                    jj = pos[j]
                    if jj>0
                        Ai[ii,jj] += q[i]*q[j]*d
                    end
                end
            end
        end
    end
    return (Ai)
end 

function HAi(ped::Pedigree)
    ii = Int64[]
    jj = Int64[]
    vv = Float64[]
    for ind in keys(ped.idMap)
        sire = ped.idMap[ind].sire
        dam  = ped.idMap[ind].dam
        sirePos = sire=="0" ? 0: ped.idMap[sire].seqID
        damPos  = dam =="0" ? 0: ped.idMap[dam ].seqID
        myPos   = ped.idMap[ind].seqID
        if sirePos>0 && damPos>0
            d = sqrt(4.0/(2 - ped.idMap[sire].f - ped.idMap[dam].f))
            push!(ii,myPos)
            push!(jj,sirePos)
            push!(vv,-0.5*d)
            push!(ii,myPos)
            push!(jj,damPos)
            push!(vv,-0.5*d)
            push!(ii,myPos)
            push!(jj,myPos)
            push!(vv,d)            
         elseif sirePos>0
            d = sqrt(4.0/(3 - ped.idMap[sire].f))
            push!(ii,myPos)
            push!(jj,sirePos)
            push!(vv,-0.5*d)
            push!(ii,myPos)
            push!(jj,myPos)
            push!(vv,d)
          elseif damPos>0
            q[1] = 0.0
            q[2] = -0.5
            d = sqrt(4.0/(3 - ped.idMap[dam].f))
            push!(ii,myPos)
            push!(jj,damPos)
            push!(vv,-0.5*d)
            push!(ii,myPos)
            push!(jj,myPos)
            push!(vv,d)            
        else
            d = 1.0
            push!(ii,myPos)
            push!(jj,myPos)
            push!(vv,d)                   
        end
    end
    return (ii,jj,vv)
end 

function  mkPed(pedFile::AbstractString) 
	df = readtable(pedFile,eltypes=[UTF8String,UTF8String,UTF8String],separator = ' ',header=false)  
	idMap = Dict()
	aij = spzeros(1,1)
	setNG = Set()
    setG  = Set()
    counts = zeros(2);
    ped = Pedigree(1,idMap,aij,setNG,setG,counts)
	fillMap!(ped,df)
	for id in keys(ped.idMap)
    	code!(ped,id)
	end
	n = ped.currentID - 1
	ped.aij = spzeros(n,n)  
	for id in keys(ped.idMap)
    	calcInbreeding!(ped,id)
	end 
	return (ped)
end

function genoSet!(fileName::AbstractString,ped::Pedigree)
    df = readtable(fileName, eltypes=[UTF8String], separator = ' ',header=false)    
    for i in df[:,1]                   
        push!(ped.setG,i)              
	end
    all = Set()                        
	for i in keys(ped.idMap)            
        push!(all,i)                            
	end
    ped.setNG = setdiff(all,ped.setG)   
	j = 1
	for i in ped.setNG
		ped.idMap[i].seqID = j
		j += 1
	end
	numberGeno = j - 1
	for i in ped.setG
		ped.idMap[i].seqID = j
		j += 1
	end	
	return (numberGeno)
end	

function getIDs(ped::Pedigree)
	n = length(ped.idMap)
	ids = Array(UTF8String,n)
	for i in ped.idMap
		ids[i[2].seqID] = i[1]
	end
	return (ids)
end	

end # of PedModule
