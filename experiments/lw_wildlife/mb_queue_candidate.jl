# The prefix is already sorted. Sort only appended items, then stably merge the
# retained prefix. Equal keys keep old items before new items, exactly as sort!.
# This changes execution cost only: no deduplication or different pruning rule.
function mb_queue_merge!(queue,prefix_length,limit,order_key)
    total=length(queue);retained=min(total,limit)
    if prefix_length==total
        resize!(queue,retained);return queue
    end
    sort!(view(queue,prefix_length+1:total);by=order_key)
    if prefix_length==0 || !isless(order_key(queue[prefix_length+1]),order_key(queue[prefix_length]))
        resize!(queue,retained);return queue
    end
    merged=similar(queue,retained)
    old_index=1;new_index=prefix_length+1
    for output_index in 1:retained
        if old_index>prefix_length || (new_index<=total && isless(order_key(queue[new_index]),order_key(queue[old_index])))
            merged[output_index]=queue[new_index];new_index+=1
        else
            merged[output_index]=queue[old_index];old_index+=1
        end
    end
    resize!(queue,retained);copyto!(queue,merged);queue
end
