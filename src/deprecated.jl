function calcAddRel!(ped::Pedigree,id1::AbstractString,id2::AbstractString)
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
