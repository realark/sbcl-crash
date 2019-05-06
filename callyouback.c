#include<stdio.h>
#include<stdlib.h>
#include <pthread.h>

void *runCallback(void *arg)
{
  void (*cback)();
  cback = (void (*))arg;

  (*cback)();
  return NULL;
}

// run cback on another thread
// and block until the callback finishes
void reg(void (*cback)())
{
  pthread_t pth;
  pthread_create(&pth, NULL, runCallback, cback);
  pthread_join(pth, NULL);
  pthread_detach(pth);
}


void doNothing()
{
}

int main()
{
  int i;
  // does the same thing as the list program.
  // even loops for another order of magnitude
  printf("Starting C program\n");
  for (i = 0; i < 1000000; ++i)
    {
      reg(&doNothing);
    }
  printf("Program finished\n");
  return 0;
}



