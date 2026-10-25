#include <mpv/client.h>
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
  if(argc<2)return 2;
  mpv_handle *p=mpv_create();
  mpv_set_option_string(p,"vo","null");
  mpv_set_option_string(p,"audio","no");
  mpv_set_option_string(p,"vid","auto");
  mpv_set_option_string(p,"pause","yes");
  mpv_initialize(p);
  int result=mpv_set_property_string(p,"vf","scale=240:136:force_original_aspect_ratio=decrease,setsar=1");
  printf("vf set result: %d (%s)\n",result,mpv_error_string(result));
  const char *load[]={"loadfile",argv[1],NULL};mpv_command(p,load);
  for(int i=0;i<100;i++){
    mpv_event *e=mpv_wait_event(p,.1);
    if(e->event_id==MPV_EVENT_PLAYBACK_RESTART)break;
  }
  char *vf=mpv_get_property_string(p,"vf");
  printf("vf readback: %s\n",vf?vf:"unavailable");mpv_free(vf);
  const char *shot[]={"screenshot-raw","video",NULL};mpv_node node;
  result=mpv_command_ret(p,shot,&node);
  printf("screenshot result: %d\n",result);
  if(result>=0&&node.format==MPV_FORMAT_NODE_MAP){
    mpv_node_list *list=node.u.list;
    for(int i=0;i<list->num;i++)if(!strcmp(list->keys[i],"w")||!strcmp(list->keys[i],"h"))
      printf("%s: %lld\n",list->keys[i],(long long)list->values[i].u.int64);
    mpv_free_node_contents(&node);
  }
  mpv_terminate_destroy(p);
  return 0;
}
